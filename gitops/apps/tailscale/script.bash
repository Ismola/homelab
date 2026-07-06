kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -

kubectl -n tailscale create secret generic operator-oauth \
  --from-literal=client_id='xxxx' \
  --from-literal=client_secret='tskey-client-xxx'