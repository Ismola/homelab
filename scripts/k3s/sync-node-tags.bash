# Para descargarlo y ejecutarlo aplicando las etiquetas:
# curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-tags.bash | sudo bash -s -- --apply
# Para previsualizar los cambios sin aplicarlos:
# curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-tags.bash | sudo bash

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

# Genera líneas con el formato "nodo|tag1,tag2". Sólo procesa los hosts de
# k3s_cluster.children.server/agent; docker_hosts y otros grupos quedan fuera.
mapfile -t inventory_nodes < <(
  awk '
    function emit_node() {
      if (node != "") {
        print node "|" tags
      }
      node = ""
      tags = ""
      reading_tags = 0
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

    node != "" && /^          tags:[[:space:]]*\[\][[:space:]]*$/ {
      reading_tags = 0
      next
    }

    node != "" && /^          tags:[[:space:]]*$/ {
      reading_tags = 1
      next
    }

    reading_tags && /^            - [a-zA-Z0-9_.-]+[[:space:]]*$/ {
      tag = $0
      sub(/^            - /, "", tag)
      sub(/[[:space:]]+$/, "", tag)
      tags = tags (tags == "" ? "" : ",") tag
      next
    }

    reading_tags && $0 !~ /^            - / {
      reading_tags = 0
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

for inventory_node in "${inventory_nodes[@]}"; do
  node="${inventory_node%%|*}"
  tags_csv="${inventory_node#*|}"
  desired_tags=()

  if [[ -n "${tags_csv}" ]]; then
    IFS=',' read -r -a desired_tags <<<"${tags_csv}"
  fi

  if ! "${kubectl_command[@]}" get node "${node}" >/dev/null 2>&1; then
    echo "El nodo ${node} está en el inventario pero no existe en Kubernetes" >&2
    exit 1
  fi

  mapfile -t current_tags < <(
    "${kubectl_command[@]}" get node "${node}" \
      --show-labels --no-headers |
      awk '{print $NF}' |
      tr ',' '\n' |
      sed -n 's#^tags\.isma\.dev/\([^=]*\)=.*#\1#p'
  )

  for tag in "${desired_tags[@]}"; do
    if [[ ! "${tag}" =~ ^[a-z0-9]([-a-z0-9_.]*[a-z0-9])?$ ]]; then
      echo "Tag no válida en ${node}: ${tag}" >&2
      exit 1
    fi
    run_kubectl label node "${node}" \
      "tags.isma.dev/${tag}=true" --overwrite
  done

  for tag in "${current_tags[@]}"; do
    if ! printf '%s\n' "${desired_tags[@]}" | grep -Fxq "${tag}"; then
      run_kubectl label node "${node}" "tags.isma.dev/${tag}-"
    fi
  done

  if printf '%s\n' "${desired_tags[@]}" | grep -Fxq longhorn; then
    run_kubectl label node "${node}" \
      node.longhorn.io/create-default-disk=true --overwrite
  else
    run_kubectl label node "${node}" \
      node.longhorn.io/create-default-disk=false --overwrite
  fi
done

if [[ "${apply}" == false ]]; then
  echo
  echo "Previsualización terminada. Ejecuta de nuevo con --apply para aplicar."
fi
