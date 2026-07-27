# Longhorn

Longhorn proporciona volúmenes persistentes replicados para los StatefulSet
del clúster. Argo CD descubre este directorio mediante `homelab-apps`.

## Nodos

Sólo `v3` y `v7` almacenan datos y ejecutan componentes de Longhorn. Son los
únicos nodos con memoria suficiente (24 GiB y 12 GiB); `rpi` (2 GiB) y los
agents (1 GiB) no tienen la tag `longhorn`.

Las tags se declaran en `ansible/inventory/inventory.yml`:

```yaml
tags:
  - longhorn
```

El script descarga el inventario de la rama `main` de GitHub. Para
previsualizar y aplicar sus tags en los objetos Node de Kubernetes:

```bash
./scripts/k3s/sync-node-tags.bash
./scripts/k3s/sync-node-tags.bash --apply
```

El script crea labels `tags.isma.dev/<tag>=true`, elimina los labels de tags
que hayan desaparecido del inventario y sincroniza además
`node.longhorn.io/create-default-disk`.

Antes de quitar `longhorn` de un nodo que ya almacena datos, deshabilita su
scheduling en la UI de Longhorn y espera a que todas sus réplicas hayan sido
evacuadas. Quitar la tag controla dónde se ejecutan los componentes, pero no
debe utilizarse como sustituto del drenado de datos.

Antes del despliegue, `v3` y `v7` deben tener instalados `open-iscsi` y los
binarios requeridos por Longhorn; `iscsid` debe estar activo. Compruébalo con
`longhornctl` v1.12.0:

```bash
longhornctl check preflight
```

Longhorn usa `/var/lib/longhorn` en el disco raíz. Para datos importantes es
preferible montar un disco dedicado en esa ruta antes del primer despliegue.

## Uso

`local-path` continúa siendo la clase predeterminada. PostgreSQL y MongoDB
deben solicitar Longhorn de forma explícita:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: longhorn
      resources:
        requests:
          storage: 20Gi
```

Los pods acceden a las bases de datos mediante sus Services `ClusterIP`. Para
acceso TCP desde la tailnet se debe publicar cada Service por separado con el
Tailscale Operator; no se deben exponer PostgreSQL ni MongoDB por Cloudflare.

Como el CSI de Longhorn también está excluido de los nodos pequeños, los pods
que monten estos PVC deben ejecutarse en uno de los nodos de almacenamiento:

```yaml
nodeSelector:
  tags.isma.dev/longhorn: "true"
```

## UI

- Tailnet: `https://longhorn`
- Cloudflare: `https://longhorn.ismola.dev`

La UI de Longhorn no implementa autenticación. La ruta pública debe protegerse
con una política de Cloudflare Access antes de habilitarla en el túnel.

Los backups de Longhorn requieren además configurar un backup target (S3/NFS)
y su Secret. Los dumps lógicos de PostgreSQL/MongoDB son complementarios a los
snapshots de volumen y deben conservarse fuera del clúster.
