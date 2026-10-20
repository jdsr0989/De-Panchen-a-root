#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  probar_rtsp.sh — encuentra la URL RTSP buena de la WOOX TR9410
#
#  Uso:  ./probar_rtsp.sh [IP]        (por defecto 10.77.0.17)
#
#  Prueba una lista de rutas candidatas con ffprobe y se queda con la que
#  responda. No usa nube: es RTSP directo contra la camara.
#
#  Antes hay que haber encendido el servidor RTSP (ver activar_rtsp.sh).
# ---------------------------------------------------------------------------
set -u
IP="${1:-10.77.0.17}"
PUERTO=554
TIMEOUT=6

CANDIDATAS=(
  "screenlive"                                                 # <url> de config.xml
  "streamtype=0"                                               # literal en Sofia
  "streamtype=1"
  "onvif1" "onvif2" "onvif0"
  "live/ch00_0" "live/ch00_1"
  "cam/realmonitor?channel=1&subtype=0"
  "cam/realmonitor?channel=1&subtype=1"
  "user=admin_password=admin_channel=1_stream=0.sdp?real_stream"
  "user=admin_password=admin_channel=1_stream=1.sdp?real_stream"
  "av0_0" "av0_1"
  "h264" "h265" "11" "12"
  "1" "0"
)

command -v ffprobe >/dev/null || { echo "[!] falta ffprobe"; exit 1; }

echo "=== 1. puertos ==="
for p in 554 80; do
  if timeout 2 bash -c "exec 3<>/dev/tcp/$IP/$p" 2>/dev/null; then
    echo "  $p ABIERTO"
  else
    echo "  $p cerrado"
  fi
done

echo
echo "=== 2. rutas candidatas (rtsp://$IP:$PUERTO/...) ==="
ENCONTRADA=""
for ruta in "${CANDIDATAS[@]}"; do
  url="rtsp://$IP:$PUERTO/$ruta"
  salida="$(ffprobe -v error -rtsp_transport tcp -timeout $((TIMEOUT*1000000)) \
            -show_entries stream=codec_name,width,height,avg_frame_rate \
            -of default=noprint_wrappers=1 "$url" 2>&1)"
  if [ $? -eq 0 ] && [ -n "$salida" ]; then
    echo "  [OK]   $url"
    echo "$salida" | sed 's/^/         /'
    ENCONTRADA="$url"
    break
  else
    motivo="$(echo "$salida" | tail -1 | cut -c1-70)"
    echo "  [--]   $ruta   ($motivo)"
  fi
done

echo
if [ -n "$ENCONTRADA" ]; then
  echo "=== ENCONTRADA: $ENCONTRADA ==="
  echo
  echo "Reproducir:  ffplay -rtsp_transport tcp '$ENCONTRADA'"
  echo "Grabar 30s:  ffmpeg -rtsp_transport tcp -i '$ENCONTRADA' -c copy -t 30 muestra.mkv"
  echo "Un fotograma: ffmpeg -rtsp_transport tcp -i '$ENCONTRADA' -frames:v 1 foto.jpg"
else
  echo "=== ninguna respondio ==="
  echo "  - el servidor RTSP no esta levantado (revisa /mnt/mtd/Config/ty/onvifinfo.json)"
  echo "  - o hace falta autenticacion: prueba admin:admin o user:123456"
  echo "  - o el puerto no es el 554"
fi
