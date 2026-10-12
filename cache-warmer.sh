#!/usr/bin/env bash
#
# cache-warmer.sh — Mantiene "caliente" la caché de un sitio web
#
# Visita periódicamente una lista de URLs para que la caché (del servidor
# o de un CDN como Cloudflare) no se enfríe. Así, el primer visitante tras
# un periodo de inactividad no se encuentra la carga lenta de una página
# generada desde cero, sino la versión ya cacheada.
#
# Uso:
#   ./cache-warmer.sh                                  # en primer plano
#   nohup ./cache-warmer.sh >> warmer.log 2>&1 &       # en segundo plano
#   kill <PID>                                         # para detenerlo
#
# Requisitos: bash, curl
#

set -u

# --- Configuración ---------------------------------------------------------
URLS=(
  "https://ejemplo.com/"
  # Añade más URLs para mantener varias páginas calientes:
  # "https://ejemplo.com/pagina-importante"
)
INTERVALO=300          # Segundos entre cada pasada (300 = 5 min)
LOG="warmer.log"       # Archivo donde registrar la actividad
# ---------------------------------------------------------------------------

echo "cache-warmer iniciado  ·  $(date '+%Y-%m-%d %H:%M:%S')  ·  PID $$" >> "$LOG"

while true; do
  for url in "${URLS[@]}"; do
    # -s silencioso · -o /dev/null descarta el cuerpo · -w mide el tiempo
    tiempo=$(curl -s -o /dev/null -w '%{time_total}s' --max-time 30 "$url" \
             || echo "ERROR")
    echo "$(date '+%Y-%m-%d %H:%M:%S')  $url  -> $tiempo" >> "$LOG"
  done
  sleep "$INTERVALO"
done
