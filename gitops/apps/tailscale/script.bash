helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="xxx" \
  --set-string oauth.clientSecret="tskey-client-xxx" \
  --set-json 'operatorConfig.nodeSelector={"tags.isma.dev/stable":"true","kubernetes.io/os":"linux"}' \
  --wait
