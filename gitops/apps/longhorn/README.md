# Backups de Longhorn

El destino por defecto es el bucket privado `longhorn` de MinIO en `h0`:

```text
s3://longhorn@us-east-1/
```

Longhorn se conecta directamente a `http://100.111.128.66:9010` por
Tailscale. La región `us-east-1` forma parte del formato de URL requerido por
Longhorn; MinIO no la utiliza para ubicar los datos.

El `RecurringJob` `databases-daily` se aplica mediante el grupo `default` a todos
los volúmenes que no tengan otra programación. Se ejecuta diariamente a las
02:00 según la zona horaria del controlador de Longhorn, conserva 14 copias
por volumen y fuerza una copia completa cada 7 copias incrementales.

## Credenciales

El usuario y el bucket se crean de forma idempotente mediante
`docker/minio/compose.yml`. Antes de desplegar el cambio, configura en el
entorno del stack de Portainer dos valores largos y aleatorios:

```dotenv
MINIO_LONGHORN_ACCESS_KEY=<access-key-aleatoria>
MINIO_LONGHORN_SECRET_KEY=<secret-key-larga-y-aleatoria>
```

Usa los mismos valores para crear el Secret fuera del repositorio:

```bash
kubectl --namespace longhorn create secret generic longhorn-minio-credentials \
  --from-literal=AWS_ACCESS_KEY_ID='<MINIO_LONGHORN_ACCESS_KEY>' \
  --from-literal=AWS_SECRET_ACCESS_KEY='<MINIO_LONGHORN_SECRET_KEY>' \
  --from-literal=AWS_ENDPOINTS='http://100.111.128.66:9010' \
  --dry-run=client -o yaml | kubectl apply -f -
```

No se usa `VIRTUAL_HOSTED_STYLE`: este MinIO no configura `MINIO_DOMAIN` y se
accede por IP, por lo que Longhorn debe utilizar peticiones path-style.

## Migración desde CIFS

El destino anterior apuntaba por CIFS a una carpeta interna de OpenCloud en el
mismo NAS. El destino `legacy-cifs` se conserva temporalmente para que las
copias antiguas sigan visibles y restaurables; las copias nuevas se escriben
exclusivamente en MinIO.

Después de comprobar al menos una restauración desde MinIO y superar el periodo
de retención deseado, se puede retirar `legacy-cifs` de
`templates/backup-policy.yaml` y eliminar el Secret
`longhorn-smb-credentials`. Cambiar de destino no copia automáticamente los
backups históricos entre backends.

## Verificación

```bash
kubectl --namespace longhorn get backuptargets.longhorn.io
kubectl --namespace longhorn get recurringjobs.longhorn.io
kubectl --namespace longhorn get backups.longhorn.io
```

El target `default` debe mostrar `AVAILABLE=true`. Además de comprobar que se
crea una copia, hay que realizar periódicamente una restauración de prueba.

MinIO está fuera del clúster K3s, pero reside en el mismo NAS. Protege frente
a la pérdida del clúster o de sus nodos, no frente a la pérdida total del NAS;
para cubrir ese caso el bucket debe replicarse o copiarse a otro equipo o
ubicación.
