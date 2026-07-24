kubectl cordon node

kubectl drain node \
  --ignore-daemonsets \
  --delete-emptydir-data

#   MAINTENACE JOBS (like upgrade)

kubectl uncordon node