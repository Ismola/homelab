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

## Actualizar K3s

Instala las dependencias Python del controlador y la colección declarada en
`requirements.yml` antes de ejecutar playbooks:

```bash
python3 -m pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

La versión objetivo está en `inventory/inventory.yml`. Para una actualización
que cruce minors, ejecuta `maintenance/upgrade-k3s.yml` una vez por cada minor
intermedia, en orden, pasando cada versión con `-e k3s_version=...`. Así el
inventario mantiene siempre declarada la versión final deseada.
