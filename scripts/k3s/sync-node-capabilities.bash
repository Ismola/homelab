# Para descargarlo y ejecutarlo aplicando las capacidades:
# curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-capabilities.bash | sudo bash -s -- --apply
# Para previsualizar los cambios sin aplicarlos:
# curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-capabilities.bash | sudo bash

#!/usr/bin/env bash

set -euo pipefail

inventory_url="https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/ansible/inventory/inventory.yml"
inventory_file="$(mktemp)"
apply=false

trap 'rm -f "${inventory_file}"' EXIT

if [[ "${1:-}" == "--apply" ]]; then
  apply=true
elif [[ $# -gt 0 ]]; then
  echo "Uso: $0 [--apply]" >&2
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Falta el comando requerido: curl" >&2
  exit 1
fi

if command -v kubectl >/dev/null 2>&1; then
  kubectl_command=(kubectl)
elif command -v k3s >/dev/null 2>&1; then
  kubectl_command=(k3s kubectl)
else
  echo "No se ha encontrado kubectl ni k3s en este nodo" >&2
  exit 1
fi

echo "Descargando inventario desde ${inventory_url}"
curl --fail --silent --show-error --location \
  "${inventory_url}" \
  --output "${inventory_file}"

# Genera líneas con el formato "nodo|capability1,capability2". Sólo procesa los hosts de
# k3s_cluster.children.server/agent; docker_hosts y otros grupos quedan fuera.
mapfile -t inventory_nodes < <(
  awk '
    function emit_node() {
      if (node != "") {
        print node "|" capabilities
      }
      node = ""
      capabilities = ""
      reading_capabilities = 0
    }

    /^k3s_cluster:$/ {
      in_k3s = 1
      next
    }

    in_k3s && /^[^[:space:]]/ {
      emit_node()
      exit
    }

    in_k3s && /^    (server|agent):$/ {
      emit_node()
      in_node_group = 1
      next
    }

    in_k3s && /^    [a-zA-Z0-9_-]+:$/ &&
      $0 !~ /^    (server|agent):$/ {
      emit_node()
      in_node_group = 0
      next
    }

    in_node_group && /^        [a-zA-Z0-9][a-zA-Z0-9_.-]*:$/ {
      emit_node()
      line = $0
      sub(/^        /, "", line)
      sub(/:$/, "", line)
      node = line
      next
    }

    node != "" && /^          capabilities:[[:space:]]*\[\][[:space:]]*$/ {
      reading_capabilities = 0
      next
    }

    node != "" && /^          capabilities:[[:space:]]*$/ {
      reading_capabilities = 1
      next
    }

    reading_capabilities && /^            - [a-zA-Z0-9_.-]+[[:space:]]*$/ {
      capability = $0
      sub(/^            - /, "", capability)
      sub(/[[:space:]]+$/, "", capability)
      capabilities = capabilities (capabilities == "" ? "" : ",") capability
      next
    }

    reading_capabilities && $0 !~ /^            - / {
      reading_capabilities = 0
    }

    END {
      emit_node()
    }
  ' "${inventory_file}"
)

if [[ ${#inventory_nodes[@]} -eq 0 ]]; then
  echo "El inventario remoto no contiene nodos en k3s_cluster" >&2
  exit 1
fi

run_kubectl() {
  if [[ "${apply}" == true ]]; then
    "${kubectl_command[@]}" "$@"
  else
    printf '%q ' "${kubectl_command[@]}"
    printf ' %q' "$@"
    printf '\n'
  fi
}

longhorn_available=false
if "${kubectl_command[@]}" get crd nodes.longhorn.io >/dev/null 2>&1; then
  longhorn_available=true
fi

for inventory_node in "${inventory_nodes[@]}"; do
  node="${inventory_node%%|*}"
  capabilities_csv="${inventory_node#*|}"
  desired_capabilities=()

  if [[ -n "${capabilities_csv}" ]]; then
    IFS=',' read -r -a desired_capabilities <<<"${capabilities_csv}"
  fi

  if ! "${kubectl_command[@]}" get node "${node}" >/dev/null 2>&1; then
    echo "El nodo ${node} está en el inventario pero no existe en Kubernetes" >&2
    exit 1
  fi

  mapfile -t current_capabilities < <(
    "${kubectl_command[@]}" get node "${node}" \
      --show-labels --no-headers |
      awk '{print $NF}' |
      tr ',' '\n' |
      sed -n 's#^capability\.isma\.dev/\([^=]*\)=.*#\1#p'
  )

  for capability in "${desired_capabilities[@]}"; do
    if [[ ! "${capability}" =~ ^[a-z0-9]([-a-z0-9_.]*[a-z0-9])?$ ]]; then
      echo "Capacidad no válida en ${node}: ${capability}" >&2
      exit 1
    fi
    run_kubectl label node "${node}" \
      "capability.isma.dev/${capability}=true" --overwrite
  done

  for capability in "${current_capabilities[@]}"; do
    if ! printf '%s\n' "${desired_capabilities[@]}" | grep -Fxq "${capability}"; then
      run_kubectl label node "${node}" "capability.isma.dev/${capability}-"
    fi
  done

  if printf '%s\n' "${desired_capabilities[@]}" | grep -Fxq storage; then
    run_kubectl label node "${node}" \
      node.longhorn.io/create-default-disk=true --overwrite
    longhorn_allow_scheduling=true
  else
    run_kubectl label node "${node}" \
      node.longhorn.io/create-default-disk=false --overwrite
    longhorn_allow_scheduling=false
  fi

  # Longhorn registra todos los nodos Kubernetes en su UI. Este campo controla
  # cuáles pueden recibir discos y réplicas, aunque los demás sigan visibles.
  if [[ "${longhorn_available}" == true ]]; then
    if "${kubectl_command[@]}" -n longhorn get nodes.longhorn.io \
      "${node}" >/dev/null 2>&1; then
      run_kubectl -n longhorn patch nodes.longhorn.io "${node}" \
        --type=merge \
        -p "{\"spec\":{\"allowScheduling\":${longhorn_allow_scheduling}}}"
    else
      echo "Longhorn todavía no ha registrado el nodo ${node}; se omite allowScheduling" >&2
    fi
  fi

  # Limpieza de los labels anteriores a este sistema de capacidades. No se
  # eliminan los metadatos isma.dev/* de provider, cpu o ram-gb.
  run_kubectl label node "${node}" \
    isma.dev/stable- \
    isma.dev/longhorn- \
    tags.isma.dev/stable- \
    tags.isma.dev/longhorn-
done

if [[ "${apply}" == false ]]; then
  echo
  echo "Previsualización terminada. Ejecuta de nuevo con --apply para aplicar."
fi
