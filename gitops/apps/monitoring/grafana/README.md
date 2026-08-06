# Grafana as code

Esta carpeta contiene la configuración de Grafana que antes vivía en la base
de datos o en ConfigMaps generados en el clúster.

## Qué gestiona cada mecanismo

- `dashboards/`: los 28 dashboards y sus tres carpetas, en formato CRD de
  Grafana. Grafana 13 los sincroniza desde Git con su Git Sync nativo.
- `git-sync/repository.json`: conexión de sólo lectura a la rama `main` y a la
  carpeta de dashboards de este repositorio.
- `../values.yaml`: datasource de Prometheus/Alertmanager, contact point,
  notification policy, SMTP y configuración de los componentes de monitoring.
- Las 134 reglas de alerta y 85 recording rules actuales pertenecen a
  `kube-prometheus-stack`; se generan de forma declarativa desde la dependencia
  vendorizada y las opciones `defaultRules` de `values.yaml`.

Grafana Git Sync sólo soporta dashboards y carpetas. Alertas, datasources,
contact points y otros recursos todavía necesitan el provisioning clásico o
el chart de Helm. Consulta la [matriz de compatibilidad de Git Sync](https://grafana.com/docs/grafana/latest/as-code/observability-as-code/git-sync/usage-limits/#resource-support-and-compatibility).

## Flujo de despliegue

1. Se cambia un dashboard JSON o la configuración de Helm en este repositorio.
2. Se hace merge/push a `main`.
3. Argo CD detecta el commit y sincroniza la aplicación `monitoring`.
4. El reconciler `git-sync-provisioner` crea o actualiza la conexión en Grafana.
5. Grafana consulta Git cada 60 segundos y aplica los dashboards.

La conexión usa Pure Git sobre HTTPS contra el repositorio público y no guarda
ningún token. `workflows` está vacío intencionadamente: Git es la fuente de la
verdad y Grafana no puede escribir commits desde la UI.

Para permitir commits o pull requests desde Grafana habría que cambiar a la
integración GitHub, crear un GitHub App o PAT de servicio con permisos mínimos y
entregar el secreto al API de provisioning. No se debe incluir ese token en el
repositorio.

## Migración inicial

El primer despliegue conserva un provider clásico vacío llamado
`sidecarProvider`. Grafana lo usa para retirar los dashboards que antes estaban
gestionados por ConfigMaps; después `git-sync-provisioner` elimina las carpetas
vacías, migra el contact point y la policy creados desde la UI a file
provisioning, y crea la conexión Git Sync. En ejecuciones posteriores sólo
reconcilia `repository.json`.

## Validación local

```bash
helm lint gitops/apps/monitoring
helm template monitoring gitops/apps/monitoring --namespace monitoring >/dev/null
find gitops/apps/monitoring/grafana/dashboards -name '*.json' -print0 \
  | xargs -0 -n1 jq -e . >/dev/null
```
