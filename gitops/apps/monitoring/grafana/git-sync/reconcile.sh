#!/bin/sh

set -eu

api=http://localhost:3000
auth="$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD"
repositories="$api/apis/provisioning.grafana.app/v0alpha1/namespaces/default/repositories"
repository_file=/etc/grafana/git-sync/repository.json

until curl -fsS "$api/api/health" >/dev/null; do
  sleep 2
done

ensure_alert_rules() {
  missing=false

  for rule_uid in calendar-sync-errors cloudflare-page-unavailable asismetro-high-memory; do
    if ! curl -fsS -u "$auth" \
      "$api/api/v1/provisioning/alert-rules/$rule_uid" >/dev/null; then
      missing=true
    fi
  done

  if [ "$missing" = "true" ]; then
    curl -fsS -u "$auth" -X POST \
      "$api/api/admin/provisioning/alerting/reload" >/dev/null
    echo "Grafana alerting provisioning reloaded"
  fi
}

while true; do
  status="$(
    curl -sS -u "$auth" -o /tmp/repository.json -w '%{http_code}' \
      "$repositories/homelab"
  )"

  if [ "$status" = "404" ]; then
    # Dejar terminar el cleanup del provider clásico antes de que Git Sync
    # reclame los mismos dashboards y carpetas.
    sleep 15

    # Estos recursos se crearon originalmente por API. Se eliminan una sola
    # vez y se vuelven a cargar desde el provisioning declarativo de Grafana.
    curl -sS -u "$auth" -X DELETE \
      "$api/api/v1/provisioning/policies" >/dev/null || true
    curl -sS -u "$auth" -X DELETE \
      "$api/api/v1/provisioning/contact-points/dftk50sv51xc0e" >/dev/null || true
    curl -fsS -u "$auth" -X POST \
      "$api/api/admin/provisioning/alerting/reload" >/dev/null

    # Las carpetas clásicas no las borra el provider cuando quedan vacías.
    # Git Sync las recreará conservando sus UID estables.
    for folder_uid in afud40pg5w6wwb ffud3x02s2fpce bfud402sa251cb; do
      curl -sS -u "$auth" -X DELETE \
        "$api/api/folders/$folder_uid" >/dev/null || true
    done

    curl -fsS -u "$auth" \
      -H 'Content-Type: application/json' \
      -X POST --data-binary "@$repository_file" \
      "$repositories" >/dev/null
    echo "Grafana Git Sync repository created"
  elif [ "$status" = "200" ]; then
    curl -fsS -u "$auth" \
      -H 'Content-Type: application/merge-patch+json' \
      -X PATCH --data-binary "@$repository_file" \
      "$repositories/homelab" >/dev/null
  else
    echo "Unexpected Grafana repository API status: $status" >&2
  fi

  # El provisioning por fichero se aplica al arrancar, pero una carpeta de
  # alertas borrada desde la UI elimina también sus reglas. Volver a cargarlo
  # únicamente cuando falta alguna regla mantiene Git como fuente de verdad.
  ensure_alert_rules

  sleep 300
done
