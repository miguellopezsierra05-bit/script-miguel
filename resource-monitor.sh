#!/usr/bin/env bash
#
# resource-monitor.sh — Monitor ligero de recursos del sistema
#
# Cada cierto intervalo registra en un archivo la fecha, la carga del
# sistema (load average) y los procesos que más CPU consumen en ese
# instante. Pensado para diagnosticar problemas intermitentes: cuando
# algo va lento "a ratos", se cruza la hora del episodio con este log
# para ver qué estaba ocupando la máquina en ese momento.
#
# El nombre del archivo lleva la fecha, así que se genera uno por día,
# y los de más de RETENCION_DIAS se borran solos para no acumular.
#
# Uso:
#   nohup ./resource-monitor.sh &     # corre en segundo plano
#   kill <PID>                        # para detenerlo
#
# Revisar:
#   tail -50 monitor-$(date +%F).log           # lo más reciente
#   grep -A6 "18:42" monitor-$(date +%F).log   # saltar a una hora concreta
#
# Requisitos: bash, uptime, ps (coreutils/procps, presentes en cualquier Linux)
#

set -u

# --- Configuración ---------------------------------------------------------
DIR="."                # Carpeta donde guardar los logs
INTERVALO=30           # Segundos entre cada muestra
TOP_N=6                # Cuántos procesos (los que más CPU) registrar
RETENCION_DIAS=2       # Borrar logs con más de N días de antigüedad
# ---------------------------------------------------------------------------

mkdir -p "$DIR"

while true; do
  archivo="$DIR/monitor-$(date +%F).log"

  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    uptime
    ps -eo user,pid,pcpu,pmem,comm --sort=-pcpu | head -n "$((TOP_N + 1))"
    echo ""
  } >> "$archivo"

  # Limpieza: borra los logs antiguos para que no crezca indefinidamente
  find "$DIR" -name 'monitor-*.log' -mtime "+$RETENCION_DIAS" -delete 2>/dev/null

  sleep "$INTERVALO"
done
