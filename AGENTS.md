# AGENTS.md

## Propósito

Este repositorio contiene la **configuración de producción** y debe considerarse la **única fuente de verdad**.

Toda configuración necesaria para desplegar o reconstruir los servicios debe estar versionada aquí. Evita realizar cambios permanentes directamente en servidores, contenedores, Portainer, Grafana, Kubernetes u otras interfaces si pueden declararse en el repositorio.

Los secretos y credenciales son la excepción: deben mantenerse fuera del repositorio.

---

## Infraestructura

La producción se divide en dos entornos:

### NAS — Docker Compose

El NAS ejecuta el `compose.yml` principal, desplegado mediante **Portainer**.

Este Compose coordina los servicios Docker definidos en sus respectivas carpetas.

* Las variables reales de producción se configuran en Portainer.
* `.env.example` debe contener todas las variables necesarias, pero nunca secretos reales.
* Los archivos persistentes o configuraciones montadas desde el host deben ubicarse en:

```text
DOCKER_PATH/<service-name>
```

Ejemplo:

```yaml
volumes:
  - ${DOCKER_PATH}/duplicati/config:/config
```

### Cluster K3s

Toda la configuración de Kubernetes debe mantenerse dentro de:

```text
gitops/
```

El cluster está gestionado mediante **Argo CD**:

* un `ApplicationSet` sincroniza automáticamente las aplicaciones desde este repositorio;
* Argo CD aplica los cambios realizados en Git;
* Argo Image Updater mantiene actualizadas las imágenes configuradas con tags como `main` o `latest`.

No deben realizarse cambios permanentes directamente con `kubectl` si pueden declararse mediante los manifiestos de `gitops/`.

---

## Reglas para agentes

Al modificar este repositorio:

* realiza únicamente los cambios necesarios;
* respeta la estructura existente;
* no introduzcas secretos;
* mantén `.env.example` actualizado;
* evita configuraciones manuales no representadas en Git;
* no elimines volúmenes, datos persistentes o recursos de producción salvo que sea necesario para la tarea;
* considera que un `push` puede provocar un despliegue automático;
* presta especial atención a monitorización y observabilidad: su configuración debe ser completamente reproducible desde este repositorio.

## Regla fundamental

> Si una configuración es necesaria para producción, debe estar representada en este repositorio.

La configuración existente únicamente en un servidor o interfaz debe considerarse **no gestionada**.
