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

## K3s

### `k3s/sync-node-tags.bash`

Descarga el inventario de Ansible desde GitHub y sincroniza las listas `tags:`
de los hosts `server` y `agent` con los objetos Node de Kubernetes.

- Crea labels `tags.isma.dev/<tag>=true`.
- Elimina labels de tags que ya no estén en el inventario.
- La tag `longhorn` también controla
  `node.longhorn.io/create-default-disk`.
- Usa `kubectl` o, si no existe, `k3s kubectl`.
- Sin `--apply` sólo muestra los comandos que ejecutaría.

Debe ejecutarse en un servidor K3s con acceso administrativo al clúster.

Previsualizar desde la máquina local mediante SSH:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-tags.bash | bash'
```

Aplicar:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/k3s/sync-node-tags.bash | bash -s -- --apply'
```

Antes de quitar `longhorn` de un nodo con datos hay que deshabilitar su
scheduling en Longhorn y esperar a que sus réplicas sean evacuadas.

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

### `backup/etcd/k3s-etcd-backup.sh`

Crea un snapshot de etcd con `k3s etcd-snapshot`, lo guarda en el montaje NFS
del NAS, escribe el resultado en `/var/log/k3s-etcd-backup.log` y elimina
snapshots con más de 14 días.

Debe instalarse en un servidor K3s que forme parte del clúster etcd:

```bash
ssh root@v3.elver-chicken.ts.net \
  'curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/backup/etcd/k3s-etcd-backup.sh -o /usr/local/bin/k3s-etcd-backup.sh && chmod 0755 /usr/local/bin/k3s-etcd-backup.sh'
```

Prueba manual:

```bash
ssh root@v3.elver-chicken.ts.net /usr/local/bin/k3s-etcd-backup.sh
```

El script espera que `/mnt/nas/etcd-backups` esté montado y escribe en una ruta
concreta de OpenCloud. Esa ruta debe revisarse antes de instalarlo.

### `backup/etcd/config.bash`

No es un script ejecutable sino una guía de configuración. Documenta:

- La entrada NFS que debe añadirse a `/etc/fstab`.
- La instalación del script de backup.
- La prueba del montaje y del snapshot.
- La entrada de cron diaria a las `03:00`.

Puede consultarse desde cualquier equipo:

```bash
curl -fsSL https://raw.githubusercontent.com/Ismola/homelab/refs/heads/main/scripts/backup/etcd/config.bash
```

Los pasos deben aplicarse manualmente por SSH en el servidor K3s elegido.

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
