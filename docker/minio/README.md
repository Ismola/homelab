# MinIO para snapshots de K3s

El Compose principal despliega MinIO en `h0` sin publicar puertos del host. El
proxy del mismo proyecto puede acceder a la API S3 mediante `minio:9000` y a la
consola mediante `minio:9001`.

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

Para publicar la API como `minio.ismola.dev`, el upstream de Nginx Proxy
Manager es `http://minio:9000`. La consola requiere un host independiente si
se desea publicar, con upstream `http://minio:9001`.
