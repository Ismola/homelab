# MongoDB

MongoDB se ejecuta como un StatefulSet de una réplica con un volumen Longhorn
de `1Gi`, ampliable posteriormente. El pod se programa únicamente en nodos con
`tags.isma.dev/longhorn=true`, donde está disponible el CSI.

## Credenciales

El Secret no se guarda en Git. Créalo antes del primer sync:

```bash
kubectl create namespace mongodb --dry-run=client -o yaml | kubectl apply -f -

kubectl -n mongodb create secret generic mongodb-auth \
  --from-literal=username=developer \
  --from-literal=password='CAMBIA_ESTA_PASSWORD'
```

Estas variables crean un usuario administrador en la base `admin`. Cambiar el
Secret después de inicializar el volumen no actualiza el usuario existente.

## Conexión

Desde pods del clúster:

```text
mongodb.mongodb.svc.cluster.local:27017
```

Desde un dispositivo conectado a la tailnet:

```text
mongodb-db:27017
```

Ejemplo:

```bash
mongosh 'mongodb://developer:CAMBIA_ESTA_PASSWORD@mongodb-db:27017/?authSource=admin'
```

El servicio de Tailscale es privado; no se crea ningún Ingress de Cloudflare.
