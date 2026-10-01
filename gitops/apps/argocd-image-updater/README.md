# Argo CD Image Updater

Esta aplicación gestiona el controlador y el recurso `ImageUpdater` en el
namespace `argocd`. El controlador conserva la versión `v1.2.2`, sus recursos,
la prioridad `homelab-critical` y la selección de nodos estables.

`vendor/install-v1.2.2.yaml` procede de
[config/install.yaml de v1.2.2](https://github.com/argoproj-labs/argocd-image-updater/blob/v1.2.2/config/install.yaml).
Se excluye el Secret vacío opcional de webhooks; las credenciales se mantienen
fuera del repositorio. El Secret `argocd/git-creds`, referenciado por
`imageupdater.yaml`, debe permitir leer y escribir este repositorio.

El parche del controlador fija `ndots: 1`. Los pods heredan sufijos de búsqueda
de Oracle VCN que pueden devolver `SERVFAIL` para nombres como
`github.com.<vcn>.oraclevcn.com`. Con este ajuste se consulta primero el nombre
externo y el controlador puede completar la escritura de digests en Git.

Argo CD adopta la instalación existente y mantiene esta configuración mediante
el `ApplicationSet`; no requiere una instalación manual adicional.
