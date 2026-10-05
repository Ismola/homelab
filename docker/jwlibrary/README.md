# Notas de JW Library

Servicio del NAS h0 que mantiene una carpeta con las notas Markdown de la copia `.jwlibrary` más reciente. Código e imagen: [Ismola/jwlibrary-notes-sync](https://github.com/Ismola/jwlibrary-notes-sync).

Está incluido en el Compose principal. La imagen de GHCR se construye para amd64 y arm64 mediante GitHub Actions. Portainer debe poder descargar `ghcr.io/ismola/jwlibrary-notes-sync:latest`; si el paquete es privado, utiliza las credenciales de GHCR configuradas en Portainer.

## Variables de Portainer

| Variable | Valor predeterminado |
|---|---|
| `JWLIBRARY_BACKUPS_PATH` | `/volume1/Archivos/opencloud/storage/users/users/934c2b07-76cc-49eb-8738-fc4ed171f4f3/4 Archives/Backup/Jw Library` |
| `JWLIBRARY_NOTES_PATH` | `/volume1/Archivos/opencloud/storage/users/users/934c2b07-76cc-49eb-8738-fc4ed171f4f3/3 Resources/Notas JW` |

Estas variables cambian únicamente las rutas de los volúmenes del NAS. Los respaldos se montan en `/backups:ro`; el destino, en `/notes`. El estado persistente se guarda en `${DOCKER_PATH}/jwlibrary-notes-sync/state`, montado en `/state`.

## Funcionamiento

Revisa las copias cada 30 segundos, espera al menos 10 segundos sin cambios y elige la más reciente por la fecha de su manifiesto. Solo lee los `.jwlibrary` situados directamente en la carpeta de entrada.

Exporta únicamente notas, con el título en el nombre del archivo y como H1. Las etiquetas aparecen como `#tag` al comienzo del cuerpo; sus espacios se convierten en `_`. No publica imágenes, playlists, subrayados ni índices.

**El destino es exclusivo del servicio: se reemplaza todo su contenido, incluyendo archivos manuales, archivos ocultos y subcarpetas.** Los cambios manuales se detectan en las revisiones y se sustituyen por el contenido de la copia, incluso si esta no ha cambiado. Al arrancar se vuelve a exportar. Una copia válida sin notas deja el destino vacío.

La copia se valida y se extrae fuera del destino antes de sustituirlo. Si falla la extracción, el destino permanece intacto. La recuperación de una publicación interrumpida utiliza `/state`; no elimines ese estado mientras el servicio trabaja. El cambio de todo el directorio no es atómico y puede observarse contenido parcial durante la publicación.

OpenCloud ya tiene `STORAGE_USERS_POSIX_WATCH_FS=true`. El servicio escribe archivos reales en la carpeta existente, sin publicar mediante enlaces simbólicos. Mantiene una única instancia y trabaja como root, igual que OpenCloud en este Compose.

Los resultados y las copias permanecen en el NAS; no se envían a GitHub ni se incluyen en la imagen. El servicio no publica puertos.

## Operación

Tras actualizar el stack de Portainer, comprueba los logs de `jwlibrary-notes-sync`. El mensaje `Destino reemplazado: N notas` confirma una exportación completa.

Para cambiar el intervalo, ajusta `POLL_INTERVAL_SECONDS` y `SETTLE_SECONDS` en este Compose y despliega el cambio. Cada reinicio vuelve a exportar la copia elegida. Los valores de las rutas se configuran en Portainer; los predeterminados y ejemplos se mantienen en Git.
