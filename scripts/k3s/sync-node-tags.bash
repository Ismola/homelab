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

for command_name in ansible-inventory curl jq kubectl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Falta el comando requerido: ${command_name}" >&2
    exit 1
  fi
done

echo "Descargando inventario desde ${inventory_url}"
curl --fail --silent --show-error --location \
  "${inventory_url}" \
  --output "${inventory_file}"

inventory_json="$(ansible-inventory -i "${inventory_file}" --list)"
mapfile -t nodes < <(
  jq -r '[.server.hosts[], .agent.hosts[]] | unique[]' <<<"${inventory_json}"
)

run_kubectl() {
  if [[ "${apply}" == true ]]; then
    kubectl "$@"
  else
    printf 'kubectl'
    printf ' %q' "$@"
    printf '\n'
  fi
}

for node in "${nodes[@]}"; do
  if ! kubectl get node "${node}" >/dev/null 2>&1; then
    echo "El nodo ${node} está en el inventario pero no existe en Kubernetes" >&2
    exit 1
  fi

  mapfile -t desired_tags < <(
    jq -r --arg node "${node}" \
      '._meta.hostvars[$node].tags // [] | unique[]' <<<"${inventory_json}"
  )
  mapfile -t current_tags < <(
    kubectl get node "${node}" -o json |
      jq -r '
        .metadata.labels // {} |
        keys[] |
        select(startswith("tags.isma.dev/")) |
        sub("^tags.isma.dev/"; "")
      '
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
