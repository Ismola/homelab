# Bibles JWPUB

https://bibles-jwpub.ismola.dev — [código y documentación](https://github.com/Ismola/bible-jwpub).

Acceso exclusivamente mediante Cloudflare y Gateway HTTPRoute, con el mismo
Gateway `traefik` que las demás aplicaciones del homelab. No hay Ingress ni
endpoint Tailscale para esta web.

El repositorio fuente sigue el proceso habitual: tests → build multi arquitectura
(amd64/arm64) → publicación en `ghcr.io/ismola/bible-jwpub:main`. Argo Image Updater
actualiza el digest en kustomization.yaml y Argo CD aplica el cambio desde Git.
La imagen debe permitir lectura al clúster, como el resto de imágenes GHCR.

Un pod con web FastAPI y worker, PVC Longhorn de 12 GiB y límites independientes.
No escalar horizontalmente: SQLite y el volumen RWO tienen un único dueño.
La importación de eBible se reanuda desde SQLite. Subidas privadas de hasta
30 MiB, con enlace aleatorio que caduca en 24 horas. No requiere servicios de pago.

PVC protegido de prune accidental; incluirlo en los respaldos Longhorn. No copiar
el DB con WAL activo: usar sqlite3.Connection.backup. Los scripts export_catalog.py
y merge_catalog.py permiten migrar solo ediciones listas y sus ZIP fuente mediante
un stream tar; nunca incluyen las subidas privadas ni copian el DB en uso.

```bash
kubectl -n bible-jwpub get pods,pvc
kubectl -n bible-jwpub logs deployment/bible-jwpub -c worker --tail=30
```

El catálogo identifica su alcance y no promete contener todas las Biblias de
Internet. Las ediciones sin permiso de redistribución quedan fuera. Los archivos
incluyen atribución y licencia originales; no hay publicidad ni cobros.
