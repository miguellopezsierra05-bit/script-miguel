# Herramientas de diagnóstico y rendimiento web

Dos scripts en Bash que escribí para resolver un problema real en producción:
un sitio web (WordPress + Moodle) alojado en un servidor modesto que **iba
lento a ratos** sin un patrón claro. En lugar de ir a ciegas, construí dos
herramientas pequeñas: una para **medir y diagnosticar** qué pasaba, y otra
para **mitigar** uno de los síntomas.

> Los datos reales del cliente (dominio, IPs, rutas) están anonimizados.
> Lo que queda es el método y el código.

---

## El contexto

- Servidor con **1 núcleo de CPU y menos de 2 GB de RAM**.
- Síntoma: la web tardaba hasta **más de un minuto** en cargar la primera vez,
  pero solo "a ratos" y sin que la CPU pareciera saturada.
- Sospecha inicial (CPU saturada) → **descartada con datos**: durante los
  episodios de lentitud la carga del sistema estaba tranquila. El problema no
  era de CPU, sino de **caché fría** y picos puntuales de origen.

El diagnóstico salió de cruzar dos fuentes: los tiempos de respuesta medidos
desde fuera y lo que el servidor estaba haciendo por dentro en ese mismo
instante. De ahí los dos scripts.

---

## 1. `resource-monitor.sh` — Monitor ligero de recursos

Cada 30 segundos registra en un log la hora, la carga del sistema, el uso de
memoria y swap, y los procesos que más CPU consumen. Un archivo por día, con
borrado automático de los antiguos para que no se acumulen.

**Para qué sirve:** cuando algo falla "a ratos", lo difícil es estar mirando
justo en el momento del fallo. Esto deja un rastro histórico: anotas la hora
del episodio y vas al log a ver qué estaba pasando.

```bash
nohup ./resource-monitor.sh &               # corre en segundo plano
tail -50 monitor-$(date +%F).log            # ver lo más reciente
grep -A12 "18:42" monitor-$(date +%F).log   # saltar a una hora concreta
```

Configurable al principio del script: carpeta, intervalo, nº de procesos y
días de retención.

**Lo que demostró:** que durante las caídas de velocidad el servidor estaba
tranquilo (carga baja), lo que redirigió la investigación hacia la caché y la
capa de CDN en vez de perder tiempo ampliando CPU.

---

## 2. `cache-warmer.sh` — Mantiene la caché "caliente"

Visita cada 5 minutos una lista de URLs para que la versión cacheada de la
página no se enfríe. Así el primer visitante tras un rato de inactividad no se
encuentra la página generándose desde cero (lenta), sino la copia ya lista.

Cada petición se registra con su **código HTTP y su tiempo de respuesta**, así
que el log sirve también para ver la evolución de la velocidad (y detectar
errores: un `502` rápido no es una buena noticia).

```bash
nohup ./cache-warmer.sh &        # bucle continuo en segundo plano
./cache-warmer.sh --once         # una sola pasada
```

Configurable: lista de URLs, intervalo y archivo de log.

**Lo que resolvió:** el síntoma más molesto (la lentitud de la "primera carga")
desapareció en las páginas que se mantenían calientes.

**Limitación conocida:** con un CDN como Cloudflare, la caché vive en cada nodo
(PoP) por separado. Lanzado desde un único servidor, el script calienta el
nodo más cercano a ese servidor, no todos los del mundo. Para un sitio con
público local (como era el caso) es suficiente; para tráfico global haría
falta lanzarlo desde varias regiones o usar una caché de nivel superior
(Tiered Cache / Cache Reserve).

---

## Ejecutarlos de forma persistente

`nohup` sirve para probar, pero si el servidor se reinicia los scripts mueren.
En producción:

**cache-warmer con cron** (una pasada cada 5 minutos):

```cron
*/5 * * * * /opt/script-miguel/cache-warmer.sh --once
```

**resource-monitor como servicio systemd** (`/etc/systemd/system/resource-monitor.service`):

```ini
[Unit]
Description=Monitor ligero de recursos
After=network.target

[Service]
ExecStart=/opt/script-miguel/resource-monitor.sh
WorkingDirectory=/var/log/resource-monitor
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo mkdir -p /var/log/resource-monitor
sudo systemctl daemon-reload
sudo systemctl enable --now resource-monitor
```

---

## Qué aprendí / qué muestra esto

- **Diagnosticar antes de actuar.** La hipótesis inicial (CPU) era la
  intuitiva y era incorrecta; los datos la tumbaron.
- **Cruzar fuentes.** Medir desde fuera (tiempos) + mirar desde dentro
  (procesos y memoria) da una imagen que ninguna de las dos da por separado.
- **Conocer los límites de tu propia herramienta** (ver la limitación del
  cache-warmer con CDN).
- Herramientas pequeñas, sin dependencias raras (solo `bash`, `curl`, `ps`,
  `free`), que funcionan en cualquier Linux y se entienden de un vistazo.

## Requisitos

`bash`, `curl`, `uptime`, `free`, `ps` — presentes por defecto en cualquier Linux.
