# MinIO para snapshots de K3s

El Compose principal despliega MinIO en `h0`. La API S3 se publica únicamente
en la dirección Tailscale de `h0`, como `http://h0:9010`; no queda enlazada a
las demás interfaces del NAS.

El almacenamiento persiste en `${DOCKER_PATH}/minio/data`. Este directorio es
exclusivo de MinIO y no debe modificarse directamente.

Antes de desplegar, el entorno del stack necesita estas variables:

```dotenv
MINIO_ROOT_USER=<usuario-administrador-aleatorio>
MINIO_ROOT_PASSWORD=<clave-administrador-larga-y-aleatoria>
MINIO_K3S_ACCESS_KEY=<access-key-aleatoria>
MINIO_K3S_SECRET_KEY=<secret-key-larga-y-aleatoria>
MINIO_K3S_BUCKET=k3s-etcd
```

`minio-k3s-init` crea el bucket y reconcilia un usuario que sólo puede listar
ese bucket y leer, escribir o eliminar sus objetos. Las credenciales no deben
guardarse en Git.

Los servidores K3s usan directamente `http://h0:9010`, por lo que la creación
de snapshots no depende de Cloudflare Access ni de un proxy HTTP. El tráfico
entre los servidores y `h0` viaja cifrado por Tailscale.
