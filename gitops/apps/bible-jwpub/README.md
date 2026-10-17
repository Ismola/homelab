# BibleShelf

https://bible-jwpub.ismola.dev — [código y documentación](https://github.com/Ismola/bible-jwpub).

Acceso exclusivamente mediante Cloudflare y Gateway HTTPRoute.

Un pod con web FastAPI y worker, PVC Longhorn de 12 GiB y Gateway HTTPRoute.
La importación del catálogo eBible comienza automáticamente y se reanuda desde
SQLite. Subidas privadas (30 MiB), con enlace aleatorio que caduca en 24 horas.
No necesita secretos nuevos ni servicios externos de pago.

El init container obtiene un commit inmutable, instala `requirements.lock` en
un volumen efímero y la web/worker lo montan de solo lectura. La imagen base
multi arquitectura está fijada por digest. Para actualizar, revisar las pruebas
del repositorio fuente y cambiar `SOURCE_REVISION` en deployment.yaml.
Este método evita depender de credenciales de GHCR y permite reconstruir el
servicio únicamente con GitOps. También hay un Dockerfile en el repo fuente.

PVC protegido de prune accidental. Incluirlo en los respaldos Longhorn. No escalar
este Deployment horizontalmente: SQLite y el volumen RWO tienen un único dueño.
No copiar el DB con WAL activo: usar `sqlite3.Connection.backup` o parar el worker
mediante un cambio de Git. Los archivos ready son inmutables por versión.

```bash
kubectl -n bible-jwpub get pods,pvc
kubectl -n bible-jwpub logs deployment/bible-jwpub -c worker --tail=30
```

El catálogo indica su alcance: no promete contener todas las Biblias de Internet.
Las ediciones sin permiso de redistribución quedan fuera. Cada archivo incorpora
la atribución original y su licencia. No hay cobros ni publicidad.
