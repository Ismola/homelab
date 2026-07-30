# PostgreSQL

PostgreSQL se ejecuta como un StatefulSet de una réplica con un volumen
Longhorn de `1Gi`, ampliable posteriormente. El pod se programa únicamente en
nodos con `capability.isma.dev/storage=true`, donde está disponible el CSI.

## Credenciales

El Secret no se guarda en Git. Créalo antes del primer sync:

```bash
kubectl create namespace postgres --dry-run=client -o yaml | kubectl apply -f -

kubectl -n postgres create secret generic postgres-auth \
  --from-literal=username=developer \
  --from-literal=password='CAMBIA_ESTA_PASSWORD' \
  --from-literal=database=development
```

Cambiar el Secret después de inicializar el volumen no cambia automáticamente
los usuarios o passwords existentes dentro de PostgreSQL.

## Conexión

Desde pods del clúster:

```text
postgres.postgres.svc.cluster.local:5432
```

Desde un dispositivo conectado a la tailnet:

```text
postgres-db:5432
```

Ejemplo:

```bash
psql 'postgresql://developer:CAMBIA_ESTA_PASSWORD@postgres-db:5432/development'
```

El servicio de Tailscale es privado; no se crea ningún Ingress de Cloudflare.

## pgAdmin

La interfaz está publicada mediante los mismos dos mecanismos que el resto de
servicios:

- Tailscale: `https://pgadmin.elver-chicken.ts.net`
- Cloudflare/Traefik: `https://pgadmin.ismola.dev`

Sus credenciales viven en el Secret `pgadmin-auth` y no se guardan en Git:

```bash
k3s kubectl -n postgres get secret pgadmin-auth \
  -o go-template='email: {{index .data "email" | base64decode}}{{"\n"}}password: {{index .data "password" | base64decode}}{{"\n"}}'
```

Para registrar PostgreSQL en pgAdmin usa `postgres` como servidor, `5432` como
puerto y las credenciales de `postgres-auth`.

## Métricas

`postgres-exporter` expone métricas únicamente dentro del clúster. El
`ServiceMonitor` de la aplicación de monitoring las incorpora a Prometheus y
Grafana carga el dashboard **PostgreSQL Database**.
