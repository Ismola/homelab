<div align="center">

# 🏠 Homelab

**Infraestructura híbrida, privada por diseño y gestionada como código**

Docker en el NAS · K3s multicloud · GitOps · Ansible · Tailscale

![Docker](https://img.shields.io/badge/h0-Docker-2496ED?logo=docker&logoColor=white)
![K3s](https://img.shields.io/badge/cluster-K3s-FFC61C?logo=k3s&logoColor=black)
![Tailscale](https://img.shields.io/badge/red-Tailscale-242424?logo=tailscale&logoColor=white)
![Cloudflare R2](https://img.shields.io/badge/objetos-Cloudflare_R2-F38020?logo=cloudflare&logoColor=white)
![Argo CD](https://img.shields.io/badge/entrega-Argo_CD-EF7B4D?logo=argo&logoColor=white)
![Ansible](https://img.shields.io/badge/automatización-Ansible-EE0000?logo=ansible&logoColor=white)

</div>

---

## Vista general

Homelab híbrido con servicios públicos y privados, almacenamiento y cómputo local y en la nube, y clúster K3s multicloud. La infraestructura se gestiona como código mediante Ansible y GitOps.

La idea, es aprovechar la capa gratuita de los distintos proveedores de nube y usar infraestructura local, para obtener un entorno de desarrollo y pruebas con alta disponibilidad y tolerancia a fallos, sin depender de un único proveedor ni de una única red física y lo más económico posible.

<!-- inventory-diagram:start -->
```mermaid
flowchart TB
    client["Clientes"]
    internet["Internet<br/>Cloudflare"]
    tailnet(("Tailscale<br/>tailnet"))
    r2[("Cloudflare R2<br/>Object Storage")]
    workloads["Workloads K3s"]
    longhorn[("Longhorn<br/>Persistent Volumes")]
    databases[("PostgreSQL · MongoDB")]

    subgraph provider_homelab["Homelab"]
        docker_h0["h0 · NAS<br/>Docker workloads"]
        k3s_rpi["rpi<br/>K3s server / worker"]
    end

    subgraph provider_google["Google Cloud"]
        k3s_v4["v4<br/>K3s agent / worker"]
    end

    subgraph provider_oracle["Oracle Cloud"]
        k3s_v3["v3<br/>K3s server / worker"]
        k3s_v7["v7<br/>K3s server / worker"]
        k3s_instance_20240424_2202["instance-20240424-2202<br/>K3s agent / worker"]
        k3s_v2["v2<br/>K3s agent / worker"]
        k3s_v5["v5<br/>K3s agent / worker"]
        k3s_v6["v6<br/>K3s agent / worker"]
    end

    subgraph docker_deployments["Docker Compose · h0"]
        compose_cloudflare["cloudflare<br/>cloudflared"]
        compose_media["media<br/>qbittorrent · jackett · radarr · sonarr · bazarr · prowlarr · plex · seerr · qbit_manage"]
        compose_networking["networking<br/>pihole · npm"]
        compose_watchtower["watchtower<br/>watchtower"]
        compose_immich["immich<br/>immich-server · immich-machine-learning · redis · database"]
        compose_opencloud["opencloud<br/>opencloud"]
        compose_duplicati["duplicati<br/>duplicati"]
        compose_gickup["gickup<br/>gickup"]
        compose_pgbackup["pgbackup<br/>pgbackups"]
        compose_minio["minio<br/>minio"]
    end

    subgraph k3s_deployments["Aplicaciones GitOps · K3s"]
        gitops_african_art_exhibition_concept["african-art-exhibition-concept"]
        gitops_apple_concept["apple-concept"]
        gitops_argocd["argocd"]
        gitops_argocd_image_updater["argocd-image-updater"]
        gitops_cakeshop_concept["cakeshop-concept"]
        gitops_calendar_subscription_hub["calendar-subscription-hub"]
        gitops_cloudflare["cloudflare"]
        gitops_etcd_backup["etcd-backup"]
        gitops_gateway_api_crds["gateway-api-crds"]
        gitops_gateway_system["gateway-system"]
        gitops_gott_calculator["gott-calculator"]
        gitops_headlamp["headlamp"]
        gitops_homepage["homepage"]
        gitops_japon_landing_concept["japon-landing-concept"]
        gitops_js_snake["js-snake"]
        gitops_jw_hitster["jw-hitster"]
        gitops_longhorn["longhorn"]
        gitops_mongodb["mongodb"]
        gitops_monitoring["monitoring"]
        gitops_open_date["open-date"]
        gitops_portfolio["portfolio"]
        gitops_postgres["postgres"]
        gitops_pro_login_animacion["pro-login-animacion"]
        gitops_sj_wedding["sj-wedding"]
        gitops_tailscale["tailscale"]
        gitops_template_next["template-next"]
        gitops_trivial_php["trivial-php"]
        gitops_zip_hider["zip-hider"]
    end

    client -->|"servicios públicos"| internet
    internet --> workloads
    client -->|"acceso privado / Split DNS"| tailnet
    internet --> docker_h0
    tailnet --- docker_h0
    docker_h0 --> docker_deployments
    tailnet --- k3s_v3
    k3s_v3 -.-> workloads
    tailnet --- k3s_v7
    k3s_v7 -.-> workloads
    tailnet --- k3s_rpi
    k3s_rpi -.-> workloads
    tailnet --- k3s_instance_20240424_2202
    k3s_instance_20240424_2202 -.-> workloads
    tailnet --- k3s_v2
    k3s_v2 -.-> workloads
    tailnet --- k3s_v4
    k3s_v4 -.-> workloads
    tailnet --- k3s_v5
    k3s_v5 -.-> workloads
    tailnet --- k3s_v6
    k3s_v6 -.-> workloads
    workloads --> k3s_deployments
    workloads --> databases
    databases --> longhorn
    workloads -->|"API S3"| r2
```
<!-- inventory-diagram:end -->

## Infraestructura

Inventario: [`ansible/inventory/inventory.yml`](ansible/inventory/inventory.yml)

El diagrama de la vista general se genera desde este inventario, los stacks
incluidos en [`docker/compose.yml`](docker/compose.yml) y las aplicaciones
seleccionadas por el
[`ApplicationSet`](gitops/apps/argocd/files/applicationset.yaml). El workflow
[`update-inventory-diagram.yml`](.github/workflows/update-inventory-diagram.yml)
lo actualiza y crea un commit automáticamente en cada push si cambian los
nodos o los servicios desplegados. También puede regenerarse localmente con:

```bash
python3 scripts/docs/generate-inventory-diagram.py
```

### Capacidades de los nodos

La planificación no depende del nombre del host ni de una cifra concreta de
RAM. Cada nodo declara en el inventario una o varias capacidades que K3s
publica como labels `capability.isma.dev/<capacidad>=true`:

| Capacidad | Uso |
| :--- | :--- |
| `lightweight` | Node exporter, Cloudflared y frontends pequeños |
| `general` | Aplicaciones con necesidades medias de CPU o memoria |
| `stable` | Controladores y servicios críticos |
| `storage` | Longhorn, sus réplicas y workloads con PVC Longhorn |

Un nodo nuevo sólo necesita la lista `capabilities` adecuada. Los argumentos de K3s aplican las etiquetas al unirse y [`sync-node-capabilities.bash`](scripts/k3s/sync-node-capabilities.bash) reconcilia cambios posteriores.

### Almacenamiento

La infraestructura combina tres tipos de almacenamiento con responsabilidades distintas:

| Capa | Uso |
| :--- | :--- |
| Longhorn en K3s | Volúmenes persistentes replicados para PostgreSQL, MongoDB y otras cargas con estado |
| `h0` | [Documentos](docker/opencloud/compose.yml), [imágenes](docker/immich/compose.yml), contenido local y copias alojadas en el NAS |
| Cloudflare R2 | Almacenamiento de objetos para las aplicaciones que necesitan una API compatible con S3 |

### Longhorn

Longhorn se ejecuta en K3s y se despliega mediante Argo CD desde
[`gitops/apps/longhorn/`](gitops/apps/longhorn/). Usa cualquier nodo con
capacidad `storage`, mantiene dos réplicas por volumen y envía backups por CIFS
a `h0`. La
`StorageClass` `longhorn` se selecciona explícitamente en las cargas que
necesitan almacenamiento persistente.

### Bases de datos

PostgreSQL y MongoDB ya se ejecutan en K3s como StatefulSets gestionados por
Argo CD, con volúmenes Longhorn y credenciales almacenadas en Secrets. Consulta
su configuración en [`gitops/apps/postgres/`](gitops/apps/postgres/README.md) y
[`gitops/apps/mongodb/`](gitops/apps/mongodb/README.md).

Las aplicaciones de K3s acceden a R2 mediante endpoint, región y bucket S3. Las credenciales y los valores sensibles se obtienen desde Secrets de Kubernetes y no se guardan directamente en el repositorio.

La configuración concreta pertenece al manifiesto de cada aplicación. El uso actual puede consultarse [aquí](gitops/apps/argocd-image-updater/imageupdater.yaml).

## Red y resolución DNS

Todos los equipos —incluidos `h0` y los nodos K3s definidos en el inventario— están conectados por Tailscale. Así, la comunicación interna no depende de que los nodos compartan proveedor o red física.

### Acceso privado

Los clientes conectados a la tailnet pueden acceder a ciertos servicios de uso personal.

| Plataforma | Método de acceso |
| :--- | :--- |
| Docker en `h0` | Conexión directa al nombre MagicDNS de `h0` y al puerto publicado por el servicio: `h0:<puerto>` |
| Aplicaciones web de K3s | Entrada privada publicada en la tailnet por el [Tailscale Operator](gitops/apps/tailscale/script.bash) |

```mermaid
flowchart LR
    client["Cliente en la tailnet"]

    client -->|"MagicDNS + puerto"| h0["h0"]
    h0 --> docker["Servicio Docker"]

    client -->|"Entrada privada"| operator["Tailscale Operator"]
    operator --> ingress["Ingress / Service K3s"]
    ingress --> app["Aplicación web"]
```

### Split DNS

Esto hace que un dominio resuelva a una IP pública desde Internet y a una IP privada desde la tailnet. Da acceso publico a los servicios, pero permite que los clientes conectados a la tailnet accedan a ellos de forma privada y más rápida. Útil en servicios que manejan grandes cantidades de datos, como servicios de [streaming](docker/media/compose.yml) o [almacenamiento](docker/opencloud/compose.yml).

Los servicios configurados usan una ruta rápida dentro de Tailscale, mientras conservan su acceso público. [Pi-hole y Nginx Proxy Manager](docker/networking/compose.yml) resuelven y enrutan el tráfico local desde `h0`.

```mermaid
flowchart LR
    tailscaleClient["Cliente conectado a Tailscale"]
    internetClient["Cliente desde Internet"]

    tailscaleDNS["DNS interno de Tailscale"]
    pihole["Pi-hole · h0"]
    npm["Nginx Proxy Manager"]
    cloudflare["Cloudflare"]
    service["Servicio Docker"]

    tailscaleClient -->|"consulta servicio.ismola.dev"| tailscaleDNS
    tailscaleDNS --> pihole
    pihole -->|"IP privada / Tailscale de h0"| npm
    npm --> service

    internetClient -->|"consulta servicio.ismola.dev"| cloudflare
    cloudflare -->|"Cloudflare Tunnel / proxy público"| service
    cloudflare -->|"Cloudflare Tunnel / proxy público"| service
```

Solo afecta a los nombres configurados; el resto usa el DNS público.

### Acceso público

Se corre un túnel de Cloudflare en [`h0`](docker/cloudflare/compose.yml) para exponer los servicios públicos y otro en el cluster [`K3s`](gitops/apps/cloudflare/deployment.yaml) para exponer las aplicaciones web. La configuración de los túneles se encuentra en los respectivos archivos de composición.

```mermaid
flowchart LR
    client["Cliente desde Internet"]
    cloudflare["Cloudflare"]
    tunnel["Túnel Cloudflare"]
    service["Servicio Docker / Aplicación K3s"]

    client --> cloudflare
    cloudflare --> tunnel
    tunnel --> service
```

## Organización del repositorio

La separación principal es:

| Ruta | Destino | Responsabilidad |
| :--- | :--- | :--- |
| [`docker/`](docker/) | `h0` | Servicios locales ejecutados con Docker Compose |
| [`gitops/apps/`](gitops/apps/) | Clúster K3s | Aplicaciones, bases de datos y Longhorn reconciliados por Argo CD |
| [`ansible/`](ansible/) | Toda la infraestructura | Inventario, variables y mantenimiento de hosts |
| [`scripts/`](scripts/README.md) | Operación | Tareas auxiliares, backups y aprovisionamiento |

## Agradecimientos

Gracias a [Tailscale](https://tailscale.com/) por simplificar la red privada que conecta todos los nodos, [GCP](https://console.cloud.google.com/?pli=1) y [Oracle Cloud](https://www.oracle.com/cloud/) por proporcionar parte de la infraestructura sobre la que funciona este homelab.

---

<div align="center">
<sub>Aprender es lo mejor ❤️</sub>
</div>
