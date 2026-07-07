# Private
## Connect H0 to container through Tailscale
> require a Tailscale tunnel running in network mode **host**

```yml
services:
  service:
    container_name: service-name
    extra_hosts:
      - "h0:${H0}"
```

# Public
## Connect to CloudFlare network
> require a CloudFlare tunnel running 

```yml
services:
  service-web:
    container_name: service-name
    expose:
      - "port"
    networks:
      - cloudflare_default
networks:
  cloudflare_default:
    external: true
```
# Tailscale — Fix Lentitud en LAN (UGDOS Rate Limit)

## Síntoma

- Velocidad via Tailscale (IP `100.111.128.66`): ~10 Mbit/s
- Velocidad via IP local (`192.168.1.110`): ~950 Mbit/s
- Ocurría desde cualquier cliente y sistema operativo
- Empezó a fallar al configurar Split DNS con Tailscale + Pi-hole + NPM

## Causa Raíz

UGREEN UGOS tiene una protección DoS integrada en iptables llamada `UGDOS_PROTECT`. Esta chain tiene una regla que **limita todo el tráfico UDP a 1000 paquetes/segundo**:

```
RETURN  udp  -- limit: avg 1000/sec burst 100
DROP    udp  -- (exceso)
```

Tailscale usa **WireGuard sobre UDP**. Con el MTU del túnel de ~1280 bytes:

```
1000 pkt/s × 1280 bytes = ~10 Mbit/s  ← exactamente el síntoma observado
```

El tráfico UDP pasaba por `UGDOS_PROTECT` antes de cualquier regla que pudiera aceptarlo, por lo que cualquier ráfaga de datos Tailscale era descartada.

> **Nota:** La conexión era directa (LAN, sin relay DERP). El problema no era DNS, routing, ni MTU del túnel — era throttling a nivel de firewall del NAS.

## Solución Aplicada

### 1. Regla iptables (inmediata)

Se añadió una excepción en `UGDOS_PROTECT` para el puerto UDP de Tailscale **antes** de la regla de rate limiting:

```bash
iptables -I UGDOS_PROTECT 1 -p udp --dport 41641 -j RETURN
```

Esto permite que el tráfico UDP del puerto 41641 salte el rate limiter y continúe al resto del stack de red normalmente.

### 2. Persistencia — Servicio systemd

Archivo: `/etc/systemd/system/tailscale-iptables.service`

```ini
[Unit]
Description=Bypass UGDOS rate limit for Tailscale UDP port
After=network.target uginit.service ugdriver.service ugbus.service ugreen-basic.target
Requires=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables -I UGDOS_PROTECT 1 -p udp --dport 41641 -j RETURN
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Habilitado con:
```bash
systemctl enable tailscale-iptables.service
```

Se ejecuta después de los servicios UGREEN (`uginit`, `ugdriver`, `ugbus`) para asegurar que `UGDOS_PROTECT` ya existe cuando se añade la regla.

### 3. Fix adicional: `src_valid_mark`

Archivo: `/etc/sysctl.d/99-tailscale.conf`

```ini
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.src_valid_mark = 1
net.ipv4.conf.default.src_valid_mark = 1
```

Necesario para el correcto funcionamiento de Tailscale como exit node con Docker en modo host.

## Resultado

| Métrica | Antes | Después |
|---------|-------|---------|
| Velocidad Tailscale | ~10 Mbit/s | ~656 Mbit/s |
| Velocidad IP local | ~950 Mbit/s | ~695 Mbit/s |
| Retransmisiones TCP | Cientos/seg | Mínimas |
## Verificación Post-Reinicio

Tras cada reinicio del NAS, verificar con:

```bash
# Comprobar que la regla está activa
sudo iptables -nvL UGDOS_PROTECT | grep 41641

# Test de velocidad
iperf3 -c h0 -t 10
```

---
*Documentado: 2026-05-22 | Fix aplicado vía GitHub Copilot CLI*
# Tailscale - Optimizacion Velocidad

## Resumen
- No encontre una mejora reproducible de throughput con los cambios probados.
- Dejé **Tailscale operativo y sano**.
- Dejé un **fix de estabilidad** en el compose: `TS_EXTRA_ARGS=--advertise-exit-node --advertise-routes=192.168.1.0/24`. Sin eso, al recrear el contenedor entraba en restart loop porque `tailscale up` exigía volver a declarar todos los flags no-default.

## Metodologia usada en esta sesion
- Intenté la medicion pedida con `iperf3 -c 100.78.241.32 -t 5 -R` desde el NAS.
- Resultado: `Connection refused` (no habia servidor iperf3 escuchando en `h1:5201` durante la sesion).
- Como alternativa, usé una **medicion proxy consistente**: 12 procesos de `ping -f -s 1200` durante 8s y lectura del delta en `tailscale0`.
- Ojo: este proxy sirve para comparar cambios entre sí, pero **no sustituye** una prueba real con iperf3 o copia de ficheros.

## Baseline util para comparar
- Baseline 1: RX=18.68 MB/s, TX=18.68 MB/s
- Baseline 2: RX=18.77 MB/s, TX=18.77 MB/s
- Baseline medio proxy: **18.73 MB/s**

## Experimento 0 - Fix de estabilidad del compose
- Problema detectado: al recrear el contenedor, Tailscale entraba en restart loop.
- Causa: el compose tenia `TS_EXTRA_ARGS=--advertise-exit-node`, pero el estado real del nodo tambien tenia `--advertise-routes=192.168.1.0/24`.
- Fix aplicado: cambié el compose a:
  - `TS_EXTRA_ARGS=--advertise-exit-node --advertise-routes=192.168.1.0/24`
- Resultado: el contenedor volvió a arrancar correctamente y este cambio **se mantiene**.

## Experimento 1a - Forzar kernel WireGuard con `TS_DEBUG_USE_WG_GO=false`
- Cambio: añadido temporalmente en el servicio `tailscale`.
- Observacion clave: los logs siguieron mostrando `configuring userspace WireGuard config`.
- Medicion inmediata tras restart: inconsistente/no reproducible.
- Medicion de confirmacion: no mostró mejora clara y estable.
- Decision: **revertido**.

## Experimento 1b - Forzar kernel WireGuard con `TS_WIREGUARD_KERNEL=1`
- Cambio: añadido temporalmente en el servicio `tailscale`.
- Logs: siguieron mostrando `configuring userspace WireGuard config`.
- Medidas:
  - Run 1: RX=18.60 MB/s, TX=18.60 MB/s
  - Run 2: RX=18.62 MB/s, TX=18.62 MB/s
- Resultado: sin mejora frente al baseline.
- Decision: **revertido**.

## Experimento 2 - Aumentar buffers UDP
- Cambio temporal:
  - `net.core.rmem_max=7500000`
  - `net.core.wmem_max=7500000`
  - `net.core.rmem_default=7500000`
  - `net.core.wmem_default=7500000`
- Medidas:
  - Run 1: RX=18.67 MB/s, TX=18.67 MB/s
  - Run 2: RX=18.71 MB/s, TX=18.71 MB/s
- Resultado: sin mejora.
- Decision: **revertido** a los valores previos (`212992`).

## Experimento 3 - IRQ affinity
- Estado inicial encontrado: la IRQ de `eth0` (IRQ 124) **ya estaba en `0-7`**.
- Medidas con ese ajuste:
  - Run 1: RX=18.53 MB/s, TX=18.53 MB/s
  - Run 2: RX=18.62 MB/s, TX=18.63 MB/s
- Resultado: no habia nada nuevo que ganar; el ajuste ya estaba aplicado.
- Decision: **sin cambios**.

## Experimento 4 - qdisc `fq` en `tailscale0`
- Intento: `tc qdisc replace dev tailscale0 root fq`
- Resultado: falló con `Specified qdisc kind is unknown`.
- Verificacion adicional: `modprobe sch_fq` devolvió `Module sch_fq not found`.
- Decision: **no aplicable en este kernel/UGOS**.

## Experimento 5 - Probar imagen `tailscale/tailscale:v1.60.0`
- Cambio: downgrade temporal desde `latest` a `v1.60.0`.
- Version verificada dentro del contenedor: `1.60.0`
- Logs: siguió usando `userspace WireGuard config`.
- Medidas:
  - Run 1: RX=18.48 MB/s, TX=18.48 MB/s
  - Run 2: RX=18.62 MB/s, TX=18.63 MB/s
- Resultado: sin mejora frente a `latest`.
- Decision: **revertido** a `tailscale/tailscale:latest`.

## Estado final dejado
- Contenedor `tailscale` levantado en `tailscale/tailscale:latest`.
- Sigue usando userspace WireGuard-Go; no conseguí forzar kernel WireGuard con las variables probadas.
- Regla iptables del puerto `41641/udp` re-verificada tras las recreaciones.
- No quedaron sysctl extra ni servicios systemd nuevos de mis pruebas.
- Compose corregido para futuros recreates:
  - `TS_EXTRA_ARGS=--advertise-exit-node --advertise-routes=192.168.1.0/24`
  - `TS_TAILSCALED_EXTRA_ARGS=--port=41641`
  - `TS_USERSPACE=false`

## Recomendacion siguiente
Para una medicion real del throughput, lo siguiente es volver a lanzar un servidor iperf3 en `h1` y repetir:

```bash
iperf3 -c 100.78.241.32 -t 5 -R
```

Si quieres seguir optimizando de verdad, el siguiente cuello de botella a atacar ya no parece ser buffers/qdisc/version, sino **conseguir que Tailscale use WireGuard de kernel de forma real** o revisar si UGOS/este kernel/esta imagen Docker lo impiden en este NAS.
