# PostgreSQL

PostgreSQL se ejecuta como un StatefulSet de una réplica con un volumen
Longhorn de `1Gi`, ampliable posteriormente. El pod se programa únicamente en
nodos con `tags.isma.dev/longhorn=true`, donde está disponible el CSI.

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
