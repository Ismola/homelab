# GitOps y bootstrap del clúster

Argo CD gestiona todas las aplicaciones de `gitops/apps/`, incluida su propia
instalación. El chart `gitops/apps/argocd` contiene Argo CD, las prioridades del
clúster y el `ApplicationSet` que descubre el resto de aplicaciones.

## Bootstrap de un clúster nuevo

Desde la raíz del repositorio, con acceso administrativo al clúster:

```bash
helm upgrade --install argocd gitops/apps/argocd \
  --namespace argocd \
  --create-namespace \
  --wait
```

Este es el único paso de arranque que no puede ejecutar Argo CD porque todavía
no existe. El comando no contiene configuración externa: instala el chart
versionado en este repositorio. El `ApplicationSet` crea después la aplicación
`argocd`, que adopta y reconcilia la misma instalación desde Git.

Las dependencias y sus archivos `Chart.lock` están vendorizados, por lo que el
bootstrap no consulta repositorios Helm ni selecciona versiones nuevas.

## Secret de Tailscale

El operador se despliega mediante la aplicación `tailscale`; ya no se instala
con un script Helm independiente. Sus credenciales OAuth siguen fuera de Git.
Consulta `gitops/apps/tailscale/README.md` para crear el Secret requerido.
