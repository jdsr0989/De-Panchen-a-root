#!/bin/sh
# ---------------------------------------------------------------------------
#  activar_rtsp.sh — enciende el servidor RTSP/ONVIF de la WOOX TR9410
#
#  POR QUE ESTA APAGADO
#    /mnt/mtd/Config/ty/onvifinfo.json  =  { "ONVIF": { "Status": 0 } }
#    y el DP de Tuya 231 (onvif_switch) esta en false.
#    Sofia solo arranca el servidor RTSP (Happytime, XMRTSP_Start) y el
#    servidor SOAP de ONVIF cuando ese switch esta a 1. Por eso 554 y 80
#    salian cerrados aunque /usr/bin/config.xml los tenga configurados.
#
#  QUE HACE
#    Pone Status=1, reinicia Sofia y espera a que el 554 escuche.
#
#  REQUISITO: arrancar con la SD puesta. dvrbox hace rmmod xm_wdt, asi que
#  NO hay watchdog de hardware: matar Sofia no reinicia la camara.
# ---------------------------------------------------------------------------

ONVIF=/mnt/mtd/Config/ty/onvifinfo.json

echo "=== ANTES ==="
cat "$ONVIF" 2>&1
netstat -tln 2>/dev/null | grep -E ":554 |:80 " || echo "  (554 y 80 cerrados)"

echo
echo "=== 1. activando ONVIF/RTSP ==="
echo '{ "ONVIF": { "Status": 1 } }' > "$ONVIF"
sync
cat "$ONVIF"

echo
echo "=== 2. reiniciando Sofia ==="
killall Sofia 2>/dev/null
sleep 3
/usr/bin/Sofia >/dev/null 2>&1 &
echo "  Sofia relanzada (pid=$!)"

echo
echo "=== 3. esperando al servidor RTSP ==="
i=0
while [ $i -lt 30 ]; do
  sleep 2
  if netstat -tln 2>/dev/null | grep -q ":554 " ; then
    echo "  RTSP escuchando tras $((i*2))s"
    break
  fi
  i=$((i+1))
done

echo
echo "=== DESPUES ==="
netstat -tln
echo
echo "=== URLS A PROBAR (need_auth=0 en config.xml) ==="
echo "  rtsp://<ip>:554/screenlive"
echo "  rtsp://<ip>:554/streamtype=0     (principal)"
echo "  rtsp://<ip>:554/streamtype=1     (substream)"
echo "  http://<ip>:80/screenlive        (rtsp_over_http=1)"
