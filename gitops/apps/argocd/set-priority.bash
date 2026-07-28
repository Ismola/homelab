#!/usr/bin/env bash

set -euo pipefail

# Argo CD se instaló fuera de este ApplicationSet, por lo que sus workloads no
# se pueden parchear declarativamente desde este directorio sin asumir cómo se
# hizo el bootstrap. Este script conserva el resto del PodTemplate y sólo añade
# la PriorityClass a todos sus controladores.
kubectl -n argocd patch deployment --all \
  --type=strategic \
  --patch '{"spec":{"template":{"spec":{"priorityClassName":"homelab-critical"}}}}'

kubectl -n argocd patch statefulset --all \
  --type=strategic \
  --patch '{"spec":{"template":{"spec":{"priorityClassName":"homelab-critical"}}}}'
