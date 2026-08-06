# Snapshot de etcd

El `CronJob` crea una única copia diaria a las 03:00, hora de Madrid. Cada Job
se programa sobre cualquier nodo con el label
`node-role.kubernetes.io/etcd`; no está ligado a un hostname concreto y los
nuevos miembros etcd son candidatos automáticamente.

El contenedor ejecuta el binario K3s del host para guardar una copia local en
el nodo elegido y otra en MinIO. Después conserva cinco copias locales en ese
nodo y catorce copias en S3, según el Secret
`kube-system/k3s-etcd-snapshot-s3-config`.

Los snapshots se observan con:

```bash
kubectl get etcdsnapshotfiles
```
