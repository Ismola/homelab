1. **Location (Host):** Aquí tienes dos opciones:
    - Escribe el nombre: **`resolve-db`** (si tu ordenador resuelve bien los nombres de Tailscale).
    - **Recomendado:** Escribe la **IP de Tailscale** que anotaste en el paso 1 (ej: `100.64.15.20`).
2. **User:** `postgres`
3. **Password:** `DaVinci`
4. **Port:** `5432` (aunque tu host use el 5432 para otra cosa, este contenedor tiene su propia red privada de Tailscale, así que usa el puerto estándar).

> Tiene que estar tailscale corriendo

![[Pasted image 20260416105628.png]]  
Para archivos es mejor (si se está en local) las unidades smb para no tener que descargar tooodo el contenido cada vez que se edita video