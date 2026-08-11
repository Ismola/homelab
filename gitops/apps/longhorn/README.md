# Backups de Longhorn

El destino por defecto reutiliza el bucket privado de etcd en MinIO, pero
mantiene los objetos de Longhorn bajo un prefijo independiente:

```text
s3://k3s-etcd@us-east-1/homelab/longhorn/
```

Longhorn se conecta directamente a `http://100.111.128.66:9010` por
Tailscale. La región `us-east-1` forma parte del formato de URL requerido por
Longhorn; MinIO no la utiliza para ubicar los datos.

El `RecurringJob` `databases-daily` se aplica mediante el grupo `default` a todos
los volúmenes que no tengan otra programación. Se ejecuta diariamente a las
02:00 según la zona horaria del controlador de Longhorn, conserva 14 copias
por volumen y fuerza una copia completa cada 7 copias incrementales.

## Credenciales compartidas con etcd

Longhorn usa el mismo access key y secret key que
`kube-system/k3s-etcd-snapshot-s3-config`. Como Kubernetes no permite
referenciar un Secret de otro namespace y Longhorn requiere nombres de claves
AWS, se copian las dos credenciales sin decodificarlas ni mostrarlas:

```bash
kubectl --namespace kube-system get secret k3s-etcd-snapshot-s3-config \
  -o json | jq '
    {
      apiVersion: "v1",
      kind: "Secret",
      metadata: {
        name: "longhorn-minio-credentials",
        namespace: "longhorn"
      },
      type: "Opaque",
      data: {
        AWS_ACCESS_KEY_ID: .data["etcd-s3-access-key"],
        AWS_SECRET_ACCESS_KEY: .data["etcd-s3-secret-key"],
        AWS_ENDPOINTS: ("http://100.111.128.66:9010" | @base64)
      }
    }
  ' | kubectl apply -f -
```

Esta duplicación es necesaria cada vez que se roten las credenciales de etcd.
Compartir el usuario reduce el aislamiento entre ambos tipos de backup, pero
evita mantener un segundo juego de credenciales, tal como se ha decidido para
este entorno.

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
