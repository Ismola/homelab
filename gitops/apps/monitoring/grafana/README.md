# Grafana as code

Esta carpeta contiene la configuración de Grafana que antes vivía en la base
de datos o en ConfigMaps generados en el clúster.

## Qué gestiona cada mecanismo

- `dashboards/`: los dashboards y sus carpetas, en formato CRD de
  Grafana. Grafana 13 los sincroniza desde Git con su Git Sync nativo.
- `git-sync/repository.json`: conexión de sólo lectura a la rama `main` y a la
  carpeta de dashboards de este repositorio.
- `../values.yaml`: datasource de Prometheus/Alertmanager, contact point,
  notification policy, SMTP y configuración de los componentes de monitoring.
- Las 134 reglas de alerta y 85 recording rules actuales pertenecen a
  `kube-prometheus-stack`; se generan de forma declarativa desde la dependencia
  vendorizada y las opciones `defaultRules` de `values.yaml`.
- Las reglas propias de Grafana, incluido el error de sincronización de Calendar
  Subscription Hub, el uso de memoria de Asismetro Automations y la
  disponibilidad de páginas públicas, se provisionan en
  `grafana.alerting.rules.yaml` dentro de `../values.yaml`.

El endpoint `/api/metrics` de Calendar Subscription Hub se descubre mediante un
`ServiceMonitor`. Las páginas publicadas por el Gateway se comprueban desde
fuera del clúster con Blackbox Exporter y un recurso `Probe`, atravesando DNS,
TLS, Cloudflare Tunnel y el servicio de origen.

## Cloudflare Analytics

El dashboard `Cloudflare Analytics` obtiene solicitudes, visitas estimadas,
transferencia y países desde GraphQL y las publica en Prometheus mediante el
exporter del chart. No usa dashboards ni plugins de Grafana Cloud.

Las credenciales no se almacenan en Git. Hay que crear un token limitado a la
zona con `Zone > Analytics > Read` y entregar el token y el Zone ID mediante:

```bash
kubectl --namespace monitoring create secret generic cloudflare-analytics \
  --from-literal=api-token='<CLOUDFLARE_API_TOKEN>' \
  --from-literal=zone-id='<CLOUDFLARE_ZONE_ID>' \
  --dry-run=client --output=yaml | kubectl apply --filename=-
```

El volumen del Secret es opcional para que Argo CD pueda desplegar antes de que
existan las credenciales. El exporter las detectará automáticamente cuando
Kubernetes actualice el volumen. `cloudflare_analytics_up` valdrá `0` si faltan
o si Cloudflare Free no habilita el dataset para la zona; el mensaje concreto
estará disponible en `cloudflare_analytics_last_error_info`.

La métrica `visits` no representa personas únicas: Cloudflare define una visita
como una carga de página iniciada desde un enlace directo o un referente
externo. Se usa porque el dataset moderno no ofrece visitantes únicos por
hostname.

Grafana Git Sync sólo soporta dashboards y carpetas. Alertas, datasources,
contact points y otros recursos todavía necesitan el provisioning clásico o
el chart de Helm. Consulta la [matriz de compatibilidad de Git Sync](https://grafana.com/docs/grafana/latest/as-code/observability-as-code/git-sync/usage-limits/#resource-support-and-compatibility).

## Flujo de despliegue

1. Se cambia un dashboard JSON o la configuración de Helm en este repositorio.
2. Se hace merge/push a `main`.
3. Argo CD detecta el commit y sincroniza la aplicación `monitoring`.
4. El reconciler `git-sync-provisioner` crea o actualiza la conexión y restaura
   el provisioning de alertas si falta alguna regla declarada.
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
