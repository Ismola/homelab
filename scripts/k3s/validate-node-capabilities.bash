#!/usr/bin/env bash

set -euo pipefail

if command -v kubectl >/dev/null 2>&1; then
  kubectl_command=(kubectl)
elif command -v k3s >/dev/null 2>&1; then
  kubectl_command=(k3s kubectl)
else
  echo "No se ha encontrado kubectl ni k3s" >&2
  exit 1
fi

errors=0
declare -A storage_by_node=()

fail() {
  echo "ERROR: $*" >&2
  errors=$((errors + 1))
}

nodes_json="$("${kubectl_command[@]}" get nodes -o json)"

while IFS=$'\t' read -r node ready lightweight general storage stable; do
  storage_by_node["${node}"]="${storage}"

  if [[ "${ready}" != "True" ]]; then
    fail "${node} no está Ready"
  fi

  if [[ "${lightweight}" != "true" && "${general}" != "true" ]]; then
    fail "${node} no tiene capacidad lightweight ni general"
  fi

  if [[ "${storage}" == "true" && "${stable}" != "true" ]]; then
    fail "${node} declara storage pero no stable"
  fi
done < <(
  jq -r '
    .items[]
    | [
        .metadata.name,
        ([.status.conditions[] | select(.type == "Ready")][0].status // ""),
        (.metadata.labels["capability.isma.dev/lightweight"] // "-"),
        (.metadata.labels["capability.isma.dev/general"] // "-"),
        (.metadata.labels["capability.isma.dev/storage"] // "-"),
        (.metadata.labels["capability.isma.dev/stable"] // "-")
      ]
    | @tsv
  ' <<<"${nodes_json}"
)

node_count="$(jq '.items | length' <<<"${nodes_json}")"
exporter_ready="$("${kubectl_command[@]}" -n monitoring get daemonset \
  monitoring-prometheus-node-exporter \
  -o jsonpath='{.status.numberReady}')"

if [[ "${exporter_ready}" != "${node_count}" ]]; then
  fail "node-exporter está Ready en ${exporter_ready}/${node_count} nodos"
fi

while IFS=$'\t' read -r pod node; do
  [[ -z "${pod}" ]] && continue
  if [[ "${storage_by_node[${node}]:-}" != "true" ]]; then
    fail "Longhorn ejecuta ${pod} en ${node}, que no tiene storage=true"
  fi
done < <(
  "${kubectl_command[@]}" -n longhorn get pods -o json |
    jq -r '
      .items[]
      | select(.status.phase != "Succeeded")
      | [.metadata.name, .spec.nodeName]
      | @tsv
    '
)

while IFS=$'\t' read -r namespace kind name container; do
  fail "${namespace}/${kind}/${name} (${container}) no define requests y limits de CPU y memoria"
done < <(
  "${kubectl_command[@]}" get deploy,statefulset,daemonset -A -o json |
    jq -r '
      .items[] as $workload
      | select(
          ["argocd", "gateway-system", "kube-system", "longhorn", "monitoring", "tailscale"]
          | index($workload.metadata.namespace)
          | not
        )
      | $workload.spec.template.spec.containers[]
      | select(
          .resources.requests.cpu == null
          or .resources.requests.memory == null
          or .resources.limits.cpu == null
          or .resources.limits.memory == null
        )
      | [
          $workload.metadata.namespace,
          $workload.kind,
          $workload.metadata.name,
          .name
        ]
      | @tsv
    '
)

if ((errors > 0)); then
  echo "Validación fallida con ${errors} error(es)." >&2
  exit 1
fi

echo "Capacidades, monitorización, Longhorn y recursos: OK (${node_count} nodos)."
