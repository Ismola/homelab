# Infraestructura

Esta es la coleccion de nodos que tengo en mi homelab, aprovisionados y mantenidos con Ansible. La infraestructura es híbrida, privada por diseño y gestionada como código.

## Capacidades de los nodos

La planificación no depende del nombre del host ni de una cifra concreta de
RAM. Cada nodo declara en el inventario una o varias capacidades que K3s
publica como labels `capability.isma.dev/<capacidad>=true`:

| Capacidad | Uso |
| :--- | :--- |
| `lightweight` | Node exporter, Cloudflared y frontends pequeños |
| `general` | Aplicaciones con necesidades medias de CPU o memoria |
| `stable` | Controladores y servicios críticos |
| `storage` | Longhorn, sus réplicas y workloads con PVC Longhorn |

Un nodo nuevo sólo necesita la lista `capabilities` adecuada. Los argumentos de K3s aplican las etiquetas al unirse y [`sync-node-capabilities.bash`](../scripts/k3s/sync-node-capabilities.bash) reconcilia cambios posteriores.
