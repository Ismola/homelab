# Scripts operativos

Los nodos no tienen clonado este repositorio. Los scripts se descargan desde
GitHub y se ejecutan remotamente por SSH o directamente desde un nodo K3s.

La URL base utilizada en los ejemplos es:

```text
https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main
```

Los cambios deben estar publicados en `main` antes de ejecutar un comando.
Conviene abrir y revisar el script antes de enviarlo directamente a `bash`,
especialmente los scripts de mantenimiento.

## Documentación

### `docs/generate-inventory-diagram.py`

Lee los hosts, roles y proveedores de `ansible/inventory/inventory.yml`, los
stacks incluidos en `docker/compose.yml` y las aplicaciones seleccionadas por
`gitops/apps/argocd/files/applicationset.yaml`. Con esos datos regenera el diagrama de
infraestructura delimitado por marcadores en el README principal. GitHub
Actions lo ejecuta automáticamente en cada push.

```bash
python3 scripts/docs/generate-inventory-diagram.py
```

Para comprobar que el README está sincronizado sin modificarlo:

```bash
python3 scripts/docs/generate-inventory-diagram.py --check
```

## K3s

### `k3s/sync-node-capabilities.bash`

Descarga el inventario de Ansible desde GitHub y sincroniza las listas
`capabilities:` de los hosts `server` y `agent` con los objetos Node.

- Crea labels `capability.isma.dev/<capacidad>=true`.
- Elimina capacidades que ya no estén en el inventario.
- La capacidad `storage` también controla
  `node.longhorn.io/create-default-disk`.
- `lightweight` recibe preferentemente frontends de hasta 128 MiB.
- `general` admite aplicaciones de mayor consumo.
- `stable` aloja controladores y servicios de infraestructura.
- `storage` aloja todos los componentes y réplicas de Longhorn.
- Elimina los antiguos `isma.dev/stable` e `isma.dev/longhorn`, pero conserva
  los labels de inventario `isma.dev/provider`, `isma.dev/cpu` y
  `isma.dev/ram-gb`.
- Usa `kubectl` o, si no existe, `k3s kubectl`.
- Sin `--apply` sólo muestra los comandos que ejecutaría.

Debe ejecutarse en un servidor K3s con acceso administrativo al clúster.

Previsualizar desde la máquina local mediante SSH:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-capabilities.bash | bash'
```

Aplicar:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-capabilities.bash | bash -s -- --apply'
```

Antes de quitar `storage` de un nodo con datos hay que deshabilitar su
scheduling en Longhorn y esperar a que sus réplicas sean evacuadas.

### `k3s/validate-node-capabilities.bash`

Comprueba que todos los nodos están `Ready`, tienen una clase de cómputo,
`storage` implica `stable`, node-exporter cubre todo el clúster, Longhorn sólo
se ejecuta en nodos `storage` y los workloads declaran CPU y memoria.

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/validate-node-capabilities.bash | bash'
```

## Mantenimiento

### `maintenance/fix-node-forward.bash`

Añade de forma idempotente una regla `iptables-nft` que permite tráfico entre
pods de la red `10.42.0.0/16`. Se usa cuando, después de una actualización, los
pods de un nodo no pueden comunicarse con otros pods o alcanzar servicios a
través de Tailscale.

Se ejecuta como root únicamente en el nodo afectado:

```bash
ssh root@NODO \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/maintenance/fix-node-forward.bash | bash'
```

La regla no se persiste automáticamente después de reiniciar, salvo que el
sistema tenga configurada persistencia para iptables.

### `maintenance/get-hpa-metrics.bash`

Muestra el estado de todos los HPA, sus Deployments, recursos, pods, consumo
real y eventos recientes de escalado o error.

Requiere `kubectl`, `jq`, acceso administrativo al clúster y Metrics Server
para que `kubectl top` devuelva datos:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/maintenance/get-hpa-metrics.bash | bash'
```

### `maintenance/cordon-node.bash`

Es una plantilla de referencia, no un script listo para ejecución: contiene el
nombre literal `node` y una pausa conceptual para realizar el mantenimiento.

El flujo debe ejecutarse desde un servidor K3s sustituyendo `NODO`:

```bash
k3s kubectl cordon NODO
k3s kubectl drain NODO --ignore-daemonsets --delete-emptydir-data
# Realizar el mantenimiento.
k3s kubectl uncordon NODO
```

El drenado elimina los datos de `emptyDir`. Antes de drenar un nodo con
Longhorn hay que comprobar el estado y la política de drenado de sus réplicas.

### `maintenance/upgrade-debian.bash`

Actualiza todos los paquetes de Debian y elimina paquetes que ya no son
necesarios:

```bash
ssh root@NODO \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/maintenance/upgrade-debian.bash | bash'
```

En nodos K3s debe ejecutarse dentro del procedimiento de mantenimiento:
cordon, drain, actualización, posible reinicio, comprobación y uncordon.

### `maintenance/upgrade-ubuntu.bash`

Actualiza paquetes de Ubuntu y después inicia `do-release-upgrade`. Un salto de
versión puede requerir interacción, reiniciar el nodo o modificar servicios.
No debe lanzarse indiscriminadamente sobre todos los nodos:

```bash
ssh -t root@NODO \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/maintenance/upgrade-ubuntu.bash | bash'
```

La opción `-t` asigna una terminal para las preguntas de `do-release-upgrade`.
En nodos K3s debe utilizarse el procedimiento completo de mantenimiento.

### `maintenance/clean-k3s-node.bash`

Elimina por completo K3s, Rancher System Agent, configuración, estado,
interfaces CNI, datos locales y binarios del nodo; después lo reinicia.

> Destructivo: no ejecutar en un nodo que deba conservar datos, etcd o
> réplicas de Longhorn. Hay que retirarlo correctamente del clúster y verificar
> backups antes de continuar.

Sólo después de confirmar el nodo objetivo:

```bash
ssh -t root@NODO \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/maintenance/clean-k3s-node.bash | bash'
```

## Backups de etcd

Un único CronJob se programa sobre cualquier miembro etcd disponible y crea
una copia local y otra remota. Si ese nodo no está disponible, Kubernetes
elige otro; los nuevos miembros etcd son candidatos automáticamente. Las
copias remotas se envían mediante S3 a MinIO en `h0` y se pueden consultar:

```bash
kubectl get etcdsnapshotfiles
```

El programador por nodo de K3s está desactivado en el inventario Ansible. El
CronJob está en [`gitops/apps/etcd-backup/`](../gitops/apps/etcd-backup/) y lee
las credenciales del Secret `kube-system/k3s-etcd-snapshot-s3-config`. El
destino está documentado en
[`docker/minio/README.md`](../docker/minio/README.md).

## Oracle Cloud

### `oracle cloud/create-instance-script.js`

Automatiza intentos de creación de una instancia en distintos dominios de
disponibilidad de Oracle Cloud. No se ejecuta por SSH ni con Node.js.

1. Abrir la página de creación de instancias de Oracle Cloud en inglés.
2. Seleccionar previamente la configuración deseada.
3. Abrir las herramientas de desarrollo del navegador.
4. Abrir el script, revisar su contenido y pegarlo en la consola:

```text
https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/oracle%20cloud/create-instance-script.js
```

El script intenta pulsar `Create` cada 30 segundos. Para detenerlo desde la
misma consola:

```javascript
clearInterval(createInterval)
```

Como depende de la estructura HTML de Oracle Cloud, puede dejar de funcionar
cuando cambie la interfaz.
