# Starter Repository

Este repositorio es una base para arrancar proyectos nuevos con una configuracion lista para desarrollo en contenedor y despliegue de imagenes Docker.

Incluye:

- Devcontainer generico con Docker-in-Docker (DinD).
- Workflow de Docker publish que sube imagenes automaticamente a GHCR.
- Ejemplos de `docker-compose` y `Dockerfile` para iniciar rapido.

La idea es usar este repo como punto de partida: agregas tu stack (Node, Python, etc.), montas tus servicios de apoyo con Docker, y dejas que el pipeline publique la imagen de tu app.

## Que trae este starter

- Devcontainer: [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json)
 	- Base Debian Bullseye.
 	- Feature de Docker-in-Docker habilitada.
 	- Preparado para ejecutar `docker` dentro del entorno de desarrollo.
- Deploy workflow: [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)
 	- Ejecuta en push a `main`.
 	- Llama al workflow de publish.
- Docker publish workflow: [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml)
 	- Construye y publica imagen multi-arquitectura (`amd64`, `arm64`) en `ghcr.io/<owner>/<repo>`.

## Archivos de ejemplo

- Compose de ejemplo: [`samples/docker-compose.sample.yml`](samples/docker-compose.sample.yml)
- Dockerfile de ejemplo: [`samples/Dockerfile.sample`](samples/Dockerfile.sample)

Estos archivos son solo referencia. Puedes copiarlos/adaptarlos a:

- `docker-compose.yml` para servicios de apoyo (db, cache, etc.).
- `Dockerfile` para la aplicacion principal.

## Flujo recomendado

1. Abre el proyecto en el devcontainer.
2. Instala el runtime de tu proyecto (Node, Python, etc.).
3. Levanta servicios auxiliares con Docker (`docker compose up -d`).
4. Desarrolla tu aplicacion.
5. Haz push a `main` y el workflow publicara la imagen automaticamente.

## Nota sobre servicios en desarrollo

Si tu proyecto necesita servicios adicionales (por ejemplo PostgreSQL, Redis, RabbitMQ), la idea de este starter es correrlos tambien con Docker desde el mismo entorno del devcontainer, aparte del servicio principal que estes programando.
