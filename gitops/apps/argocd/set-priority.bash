#!/usr/bin/env bash

set -euo pipefail

# Argo CD se instaló fuera de este ApplicationSet, por lo que sus workloads no
# se pueden parchear declarativamente desde este directorio sin asumir cómo se
# hizo el bootstrap. También migramos el selector estable antiguo al que
# mantiene scripts/k3s/sync-node-capabilities.bash.
patch='{"spec":{"template":{"spec":{"priorityClassName":"homelab-critical","nodeSelector":{"isma.dev/stable":null,"capability.isma.dev/stable":"true"}}}}}'

for resource_type in deployment statefulset; do
  while IFS= read -r resource; do
    kubectl -n argocd patch "${resource}" --type=merge --patch "${patch}"
  done < <(kubectl -n argocd get "${resource_type}" -o name)
done
