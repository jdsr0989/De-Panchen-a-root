#!/bin/sh
# ---------------------------------------------------------------------------
#  sd_run.sh - autorun de laboratorio para la WOOX TR9410 (equipo propio)
#
#  Se coloca en la RAIZ de la 1a particion FAT de la microSD.
#  dvrbox lo ejecuta en cada arranque, como root y sin verificar nada:
#
#     access("/home/sd_run.sh")
#     system("rmmod xm_wdt");
#     sleep(1);
#     execl("/bin/sh", "sh", "/home/sd_run.sh", NULL);
#
#  dvrbox monta /dev/mmcblk0p1 en /home; si esa particion no existe (tarjeta
#  "superfloppy") monta /dev/mmcblk0 entero.  En ambos casos con
#  mount(..., "vfat", 4, 0)  ->  FAT, NO exFAT ni NTFS.
#
#  OJO - execl() SUSTITUYE el proceso dvrbox:
#    * macGuarder (TCP 9530) y udp_server (9777) no llegan a arrancar
#    * dvrbox ya no lanza "Sofia &" -> la lanzamos nosotros
#    * xm_wdt queda descargado -> Sofia avisa "!XMSDK_WDT_Create()" (no es fatal)
#
#  HISTORIAL DE BUGS (para no repetirlos):
#    v1: el vigilante usaba [ -s /proc/PID/cmdline ], y en procfs el tamano
#        SIEMPRE es 0 -> nunca reconocia su propio telnetd y lo mataba cada
#        10 s. Ahora se comprueba el PUERTO 2323, que es nuestro en exclusiva.
#    v1: la salida de Sofia se redirigia al log -> 315 KB en un jffs2 de 832 KB.
# ---------------------------------------------------------------------------

PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

LOG=/mnt/mtd/Log/sd_run.log
mkdir -p /mnt/mtd/Log 2>/dev/null
: >> "$LOG" 2>/dev/null || LOG=/tmp/sd_run.log

# se conserva el log del arranque anterior y se empieza uno nuevo (jffs2 es pequeno)
if [ -f "$LOG" ] ; then
  cp -f "$LOG" "$LOG.prev" 2>/dev/null
  : > "$LOG" 2>/dev/null
fi

log() { echo "$(date) [sd_run] $*" >> "$LOG" 2>&1; }

# --- utilidades -------------------------------------------------------------
# puerto_abierto <puerto>: hay algo escuchando en ese puerto TCP
# OJO: netstat -tn solo muestra conexiones establecidas; hace falta -l.
puerto_abierto() {
  netstat -tln 2>/dev/null | grep -q ":$1 .*LISTEN"
}

# arranca_telnet: fuera cualquier telnetd (el de rcS usa /bin/login y pide
# contrasena) y ponemos los nuestros, que dan shell directa de root.
arranca_telnet() {
  killall telnetd 2>/dev/null
  sleep 1
  telnetd -l /bin/sh
  telnetd -l /bin/sh -p 2323 2>/dev/null
  log "telnetd relanzado: 23 (principal) y 2323 (garantizada)"
}

# ---------------------------------------------------------------------------
# 0. Traza del arranque
# ---------------------------------------------------------------------------
{
  echo "=========================================================="
  echo "sd_run.sh arrancado: $(date)"
  echo "pid=$$"
  echo "--- ps ---"        ; ps 2>&1
  echo "--- mount ---"     ; mount 2>&1
  echo "--- /home ---"     ; ls -la /home 2>&1
  echo "--- modulos ---"   ; lsmod 2>&1
  echo "--- netstat ---"   ; netstat -tln 2>&1
  echo "=========================================================="
} >> "$LOG" 2>&1

# ---------------------------------------------------------------------------
# 1. Shell de root por telnet, SIN login
# ---------------------------------------------------------------------------
arranca_telnet

# ---------------------------------------------------------------------------
# 2. Vigilante
# ---------------------------------------------------------------------------
# El 2323 es nuestro en exclusiva: si esta a la escucha, es nuestro telnetd.
# (Comprobar el puerto es fiable; mirar /proc/PID/cmdline no lo era.)
(
  while : ; do
    if ! puerto_abierto 2323 ; then
      log "2323 no escucha -> relanzando telnetd"
      arranca_telnet
    fi
    sleep 15
  done
) >> "$LOG" 2>&1 &

# ---------------------------------------------------------------------------
# 3. Mantener la camara operativa
# ---------------------------------------------------------------------------
# dvrbox era quien lanzaba la app. La salida NO va al log: Sofia ya escribe
# en /mnt/mtd/Log/sofia.log por su cuenta y el jffs2 solo tiene 832 KB.
if [ -x /usr/bin/Sofia ] ; then
  /usr/bin/Sofia >/dev/null 2>&1 &
  log "Sofia lanzada (pid=$!)"
fi

# ---------------------------------------------------------------------------
# 4. xm_wdt se quedo descargado (lo hace dvrbox antes del execl). Sofia se
#    queja al crear su watchdog pero sigue funcionando. Si aparecieran
#    reinicios, descomentar:
# ---------------------------------------------------------------------------
# insmod /usr/lib/modules/xm_wdt.ko && log "xm_wdt recargado"

log "fin del arranque de sd_run.sh"
exit 0
