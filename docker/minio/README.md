# MinIO para backups de K3s y Longhorn

El Compose principal despliega MinIO en `h0`. La API S3 se publica únicamente
en la dirección Tailscale de `h0`, como `http://h0:9010`; no queda enlazada a
las demás interfaces del NAS.

El almacenamiento persiste en `${DOCKER_PATH}/minio/data`. Este directorio es
exclusivo de MinIO y no debe modificarse directamente.

El entorno del stack necesita estas variables:

```dotenv
MINIO_ROOT_USER=<usuario-administrador-aleatorio>
MINIO_ROOT_PASSWORD=<clave-administrador-larga-y-aleatoria>
MINIO_LONGHORN_ACCESS_KEY=<access-key-aleatoria>
MINIO_LONGHORN_SECRET_KEY=<secret-key-larga-y-aleatoria>
```

El servicio de un solo uso `minio-bootstrap` crea o actualiza el bucket
privado `longhorn`, un usuario dedicado y la política mínima necesaria para
listar, leer, escribir y eliminar sus backups. El contenedor debe finalizar
con código `0`; puede comprobarse después de desplegar el stack con:

```bash
docker compose -f docker/compose.yml logs minio-bootstrap
```

La misma access key y secret key deben guardarse en el Secret de Kubernetes
`longhorn/longhorn-minio-credentials`, siguiendo
[`gitops/apps/longhorn/README.md`](../../gitops/apps/longhorn/README.md).

El bucket `k3s-etcd`, su política y el usuario limitado de K3s se crearon
durante el bootstrap inicial. Sus credenciales están en el Secret
`kube-system/k3s-etcd-snapshot-s3-config`; también deben conservarse fuera del
clúster para poder restaurar un snapshot durante una recuperación total.

Los servidores K3s usan directamente `http://h0:9010`, por lo que la creación
de snapshots no depende de Cloudflare Access ni de un proxy HTTP. El tráfico
entre los servidores y `h0` viaja cifrado por Tailscale.
