# Dockerfile de ejemplo para una app Node.js.
# Si usas Python u otro stack, adapta esta base.
FROM node:22-alpine

WORKDIR /app

# Copia archivos de dependencias primero para aprovechar cache.
COPY package*.json ./
RUN npm ci

# Copia el resto del proyecto.
COPY . .

EXPOSE 3000

# Ajusta este comando al script de tu proyecto.
CMD ["npm", "run", "dev"]
