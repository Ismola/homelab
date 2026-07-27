kubectl cordon node

kubectl drain node \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --disable-eviction \
  --force \
  --timeout=5m

#   MAINTENACE JOBS (like upgrade)

kubectl uncordon node