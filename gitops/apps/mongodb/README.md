# MongoDB

MongoDB se ejecuta como un StatefulSet de una réplica con un volumen Longhorn
de `1Gi`, ampliable posteriormente. El pod se programa únicamente en nodos con
`capability.isma.dev/storage=true`, donde está disponible el CSI.

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

## mongo-express

La interfaz está publicada mediante los mismos dos mecanismos que el resto de
servicios:

- Tailscale: `https://mongo-express.elver-chicken.ts.net`
- Cloudflare/Traefik: `https://mongo-express.ismola.dev`

La interfaz no solicita autenticación HTTP. Ten en cuenta que esto también se
aplica al acceso publicado mediante Cloudflare.

La URI que usa la interfaz se almacena por separado en el Secret
`mongo-express-connection`, para no incluir la contraseña de MongoDB en los
manifiestos.

## Métricas

`mongodb-exporter` expone métricas únicamente dentro del clúster. El
`ServiceMonitor` de la aplicación de monitoring las incorpora a Prometheus y
Grafana carga el dashboard **MongoDB**.
