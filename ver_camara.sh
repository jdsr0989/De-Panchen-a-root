#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  ver_camara.sh — abre el stream de la WOOX TR9410 por LAN (sin nube)
#
#  Uso:
#     ./ver_camara.sh              ver en vivo (HEVC 2304x1296)
#     ./ver_camara.sh sub          ver el substream (H264 480x272, mas ligero)
#     ./ver_camara.sh grabar [N]   grabar N segundos (por defecto 60), sin recodificar
#     ./ver_camara.sh foto [f.jpg] un fotograma
#     ./ver_camara.sh shell        shell de root por telnet
#     ./ver_camara.sh estado       comprobar puertos y stream
#     ./ver_camara.sh buscar       buscar la camara en la red (si cambio de IP)
#
#  Se puede forzar la IP con la variable CAM:
#     CAM=10.77.0.99 ./ver_camara.sh
# ---------------------------------------------------------------------------
set -u

CAM="${CAM:-10.77.0.17}"
PUERTO_RTSP=554
MODO="${1:-ver}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rojo()  { echo -e "\033[1;31m$*\033[0m"; }
verde() { echo -e "\033[1;32m$*\033[0m"; }

existe_puerto() { timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

case "$MODO" in

  # ---------------------------------------------------------------- ver en vivo
  ver|sub)
    RUTA="streamtype=0"; TITULO="TR9410 principal H265 2304x1296"
    [ "$MODO" = "sub" ] && { RUTA="streamtype=1"; TITULO="TR9410 substream H264 480x272"; }
    existe_puerto "$CAM" $PUERTO_RTSP || {
      rojo "[!] $CAM:$PUERTO_RTSP cerrado."
      echo "    - la camara tarda ~40-60 s desde el encendido en abrir el RTSP"
      echo "    - si cambio de IP:  $0 buscar"
      exit 1
    }
    verde "[*] $TITULO   (q o ESC para salir)"
    exec ffplay -loglevel warning -rtsp_transport tcp \
         -window_title "$TITULO" -fflags nobuffer -flags low_delay \
         "rtsp://$CAM:$PUERTO_RTSP/$RUTA"
    ;;

  # ------------------------------------------------------------------- grabar
  grabar)
    SEG="${2:-60}"
    SALIDA="grabacion_$(date +%Y%m%d_%H%M%S).mkv"
    verde "[*] grabando $SEG s del stream principal -> $SALIDA"
    ffmpeg -loglevel warning -rtsp_transport tcp \
           -i "rtsp://$CAM:$PUERTO_RTSP/streamtype=0" \
           -c copy -t "$SEG" -y "$SALIDA" && verde "[+] hecho: $(ls -lh "$SALIDA" | awk '{print $5}')"
    ;;

  # -------------------------------------------------------------------- foto
  foto)
    SALIDA="${2:-foto_$(date +%Y%m%d_%H%M%S).jpg}"
    verde "[*] capturando un fotograma -> $SALIDA"
    ffmpeg -loglevel warning -rtsp_transport tcp \
           -i "rtsp://$CAM:$PUERTO_RTSP/streamtype=0" \
           -frames:v 1 -update 1 -y "$SALIDA" && verde "[+] hecho: $(ls -lh "$SALIDA" | awk '{print $5}')"
    ;;

  # ------------------------------------------------------------ shell de root
  shell)
    existe_puerto "$CAM" 23 || { rojo "[!] $CAM:23 cerrado (¿esta la SD puesta?)"; exit 1; }
    verde "[*] shell de root en $CAM (Ctrl-C o Ctrl-D para salir)"
    exec python3 "$AQUI/cam.py" --port 23 --sh
    ;;

  # ------------------------------------------------------------------ estado
  estado)
    echo "=== $CAM ==="
    ping -c1 -W1 "$CAM" >/dev/null 2>&1 && verde "  ping  OK" || rojo "  ping  FALLA"
    for p in 23 2323 554 8899 6668; do
      if existe_puerto "$CAM" "$p"; then verde "  $p  ABIERTO"; else echo "  $p  cerrado"; fi
    done
    echo
    echo "  RTSP:  rtsp://$CAM:$PUERTO_RTSP/streamtype=0   (H265)"
    echo "         rtsp://$CAM:$PUERTO_RTSP/streamtype=1   (H264)"
    ;;

  # ------------------------------------------------------------------ buscar
  buscar)
    BASE="$(echo "$CAM" | cut -d. -f1-3)"
    verde "[*] buscando camaras con el 554 abierto en $BASE.0/24 ..."
    for i in $(seq 1 254); do
      ( existe_puerto "$BASE.$i" 554 && echo "  ENCONTRADA: $BASE.$i" ) &
    done
    wait
    echo "(fin del barrido)"
    ;;

  *)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
