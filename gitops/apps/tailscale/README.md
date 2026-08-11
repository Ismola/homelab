# Tailscale Kubernetes Operator

Argo CD instala y actualiza el operador mediante el chart oficial fijado en
`Chart.yaml`. La única configuración externa es el Secret con las credenciales
OAuth, que no debe almacenarse en Git.

Antes del primer sync, crea el Secret esperado por el chart:

```bash
kubectl create namespace tailscale --dry-run=client --output=yaml \
  | kubectl apply --filename=-

kubectl --namespace tailscale create secret generic operator-oauth \
  --from-literal=client_id='<TAILSCALE_OAUTH_CLIENT_ID>' \
  --from-literal=client_secret='<TAILSCALE_OAUTH_CLIENT_SECRET>'
```

El cliente OAuth debe tener los permisos y el tag requeridos por el operador.
El Secret se conserva fuera del repositorio; el resto de la instalación y la
configuración se reconcilia desde Git.
