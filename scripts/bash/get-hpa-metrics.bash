kubectl get hpa -A -o json |
jq -r '.items[] | [
  .metadata.namespace,
  .metadata.name,
  .spec.scaleTargetRef.kind,
  .spec.scaleTargetRef.name
] | @tsv' |
while IFS=$'\t' read -r NS HPA KIND TARGET; do
  echo
  echo "======================================================================"
  echo "NAMESPACE: $NS"
  echo "HPA:       $HPA"
  echo "OBJETIVO:  $KIND/$TARGET"
  echo "======================================================================"

  echo
  echo "=== ESTADO ACTUAL DEL HPA ==="
  kubectl get hpa "$HPA" -n "$NS" -o wide

  echo
  echo "=== RÉPLICAS Y CONDICIONES ==="
  kubectl get hpa "$HPA" -n "$NS" -o json |
  jq -r '
    "Mínimas:  \(.spec.minReplicas // 1)",
    "Máximas:  \(.spec.maxReplicas)",
    "Actuales: \(.status.currentReplicas // 0)",
    "Deseadas: \(.status.desiredReplicas // 0)",
    "",
    "Condiciones:",
    (
      .status.conditions[]?
      | "  \(.type)=\(.status) | \(.reason): \(.message)"
    )
  '

  if [ "$KIND" = "Deployment" ]; then
    echo
    echo "=== ESTADO DEL DEPLOYMENT ==="

    kubectl get deployment "$TARGET" -n "$NS" \
      -o custom-columns='NAME:.metadata.name,DESEADAS:.spec.replicas,ACTUALIZADAS:.status.updatedReplicas,READY:.status.readyReplicas,DISPONIBLES:.status.availableReplicas,NO_DISPONIBLES:.status.unavailableReplicas'

    SELECTOR=$(kubectl get deployment "$TARGET" -n "$NS" -o json |
      jq -r '
        .spec.selector.matchLabels
        | to_entries
        | map("\(.key)=\(.value)")
        | join(",")
      ')

    echo
    echo "Selector: $SELECTOR"

    echo
    echo "=== RECURSOS ASIGNADOS POR CONTENEDOR ==="

    kubectl get deployment "$TARGET" -n "$NS" -o json |
    jq -r '
      .spec.template.spec.containers[]
      | [
          .name,
          (.resources.requests.cpu // "-"),
          (.resources.requests.memory // "-"),
          (.resources.limits.cpu // "-"),
          (.resources.limits.memory // "-")
        ]
      | @tsv
    ' |
    awk 'BEGIN {
      printf "%-30s %-14s %-14s %-14s %-14s\n",
             "CONTENEDOR","REQ_CPU","REQ_MEM","LIMIT_CPU","LIMIT_MEM"
    }
    {
      printf "%-30s %-14s %-14s %-14s %-14s\n",
             $1,$2,$3,$4,$5
    }'

    echo
    echo "=== PODS DEL DEPLOYMENT ==="

    kubectl get pods -n "$NS" -l "$SELECTOR" \
      -o custom-columns='POD:.metadata.name,NODO:.spec.nodeName,FASE:.status.phase,READY:.status.containerStatuses[*].ready,REINICIOS:.status.containerStatuses[*].restartCount,IP:.status.podIP,CREADO:.metadata.creationTimestamp'

    echo
    echo "=== CONSUMO REAL DE LOS PODS ==="

    kubectl top pods -n "$NS" -l "$SELECTOR" --containers 2>/dev/null ||
      echo "No se pudieron obtener métricas desde metrics-server"
  fi

  echo
  echo "=== ÚLTIMOS ESCALADOS DECIDIDOS POR EL HPA ==="

  EVENTS=$(kubectl get events -n "$NS" \
    --field-selector "involvedObject.kind=HorizontalPodAutoscaler,involvedObject.name=$HPA" \
    -o json)

  echo "$EVENTS" |
  jq -r '
    [
      .items[]
      | select(.reason == "SuccessfulRescale")
      | {
          fecha: (
            .eventTime
            // .series.lastObservedTime
            // .lastTimestamp
            // .metadata.creationTimestamp
          ),
          repeticiones: (.series.count // .count // 1),
          mensaje: .message
        }
    ]
    | sort_by(.fecha)
    | reverse
    | .[:10]
    | if length == 0 then
        "No hay eventos recientes de escalado"
      else
        .[]
        | "\(.fecha) | x\(.repeticiones) | \(.mensaje)"
      end
  '

  echo
  echo "=== ERRORES O AVISOS RECIENTES DEL HPA ==="

  echo "$EVENTS" |
  jq -r '
    [
      .items[]
      | select(
          .type == "Warning"
          or .reason == "FailedGetResourceMetric"
          or .reason == "FailedComputeMetricsReplicas"
        )
      | {
          fecha: (
            .eventTime
            // .series.lastObservedTime
            // .lastTimestamp
            // .metadata.creationTimestamp
          ),
          repeticiones: (.series.count // .count // 1),
          motivo: .reason,
          mensaje: .message
        }
    ]
    | sort_by(.fecha)
    | reverse
    | .[:5]
    | if length == 0 then
        "Sin errores recientes"
      else
        .[]
        | "\(.fecha) | x\(.repeticiones) | \(.motivo): \(.mensaje)"
      end
  '
done