#!/usr/bin/env python3
"""
cam.py — cliente telnet fiable para la WOOX TR9410.

Diferencia con sd_connect.py: aqui se lee HASTA EL PROMPT, no un tiempo fijo.
Asi no se pierde salida ni se solapan comandos.

Uso:
    ./cam.py 'comando1' 'comando2' ...
    ./cam.py --sh                      shell interactiva
    ./cam.py --port 2323 'id'
"""
import socket
import select
import sys
import time

IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
PROMPT = b"~ # "

NEG_REPLY = bytes([
    IAC, WONT, 1,     # DO ECHO    -> WONT
    IAC, WONT, 31,    # DO NAWS    -> WONT
    IAC, DONT, 1,     # WILL ECHO  -> DONT
    IAC, DONT, 3,     # WILL SGA   -> DONT
])


def strip(data: bytes) -> bytes:
    """Quita secuencias IAC de una respuesta ya negociada."""
    out = bytearray()
    i = 0
    while i < len(data):
        if data[i] != IAC:
            out.append(data[i])
            i += 1
            continue
        if i + 1 >= len(data):
            break
        cmd = data[i + 1]
        if cmd == IAC:
            out.append(IAC)
            i += 2
        elif cmd == SB:
            j = i + 2
            while j + 1 < len(data) and not (data[j] == IAC and data[j + 1] == SE):
                j += 1
            i = j + 2
        else:
            i += 3 if cmd in (DO, DONT, WILL, WONT) else 2
    return bytes(out)


class Cam:
    def __init__(self, host="10.77.0.17", port=23, timeout=4.0, verbose=True):
        self.verbose = verbose
        self.timeout = timeout
        self.s = socket.create_connection((host, port), timeout=8)
        self.s.setblocking(False)
        self.s.sendall(NEG_REPLY)
        self.buf = b""
        self._recolecta(1.5)                       # prompt inicial
        self.buf = b""

    def _recolecta(self, espera):
        """Lee durante 'espera' segundos y acumula."""
        fin = time.time() + espera
        while time.time() < fin:
            r, _, _ = select.select([self.s], [], [], 0.2)
            if not r:
                continue
            try:
                c = self.s.recv(8192)
            except OSError:
                break
            if not c:
                raise ConnectionError("el servidor cerro la conexion")
            self.buf += strip(c)

    def run(self, cmd, espera_max=8.0):
        """Manda un comando y lee hasta que reaparezca el prompt."""
        if self.verbose:
            print(f"\n$ {cmd}", flush=True)
        self.buf = b""
        self.s.sendall(cmd.encode() + b"\n")
        fin = time.time() + espera_max
        while time.time() < fin:
            self._recolecta(0.3)
            if self.buf.rstrip().endswith(PROMPT.rstrip()) and len(self.buf) > 2:
                break
        texto = self.buf.decode("utf-8", "replace")
        # quitar el eco del comando y el prompt final
        lineas = texto.splitlines()
        if lineas and lineas[0].strip() == cmd.strip():
            lineas = lineas[1:]
        if lineas and lineas[-1].strip() in ("~ #", "#", "~ #"):
            lineas = lineas[:-1]
        salida = "\n".join(lineas)
        if self.verbose:
            print(salida, flush=True)
        return salida

    def close(self):
        try:
            self.s.close()
        except OSError:
            pass


def main():
    args = sys.argv[1:]
    port = 23
    if "--port" in args:
        i = args.index("--port")
        port = int(args[i + 1])
        del args[i:i + 2]
    interactivo = "--sh" in args
    if interactivo:
        args.remove("--sh")

    push = None
    if "--push" in args:
        i = args.index("--push")
        push = (args[i + 1], args[i + 2])
        del args[i:i + 3]

    try:
        c = Cam(port=port)
    except OSError as e:
        print(f"[!] no se pudo conectar a 10.77.0.17:{port}: {e}")
        return 1

    if push:
        local, remote = push
        with open(local, "r") as fh:
            contenido = fh.read()
        delim = "SDRUN_EOF_7f3a91"
        if delim in contenido:
            print("[!] el delimitador aparece en el fichero; abortando")
            c.close()
            return 1
        print(f"[*] subiendo {local} -> {remote} ({len(contenido)} bytes)")
        c.run(f"cat > {remote} << '{delim}'\n{contenido}\n{delim}")
        c.run(f"chmod 755 {remote}")
        c.run(f"ls -l {remote}")
        c.run(f"sh -n {remote} && echo SINTAXIS_OK")
        c.close()
        return 0

    if interactivo:
        # Modo crudo: un hilo vuelca lo que llega (con el eco del pty incluido,
        # como una sesion normal) y el hilo principal manda lo que teclees.
        import threading

        print("[*] shell interactiva. Ctrl-C o Ctrl-D para salir.")
        print("[*] (no hay 'help' ni 'uname': prueba 'busybox --list')")

        def lector():
            while True:
                try:
                    r, _, _ = select.select([c.s], [], [], 0.5)
                except (OSError, ValueError):
                    return
                if not r:
                    continue
                try:
                    data = c.s.recv(8192)
                except OSError:
                    return
                if not data:
                    sys.stdout.write("\n[!] la camara cerro la conexion\n")
                    return
                sys.stdout.write(strip(data).decode("utf-8", "replace"))
                sys.stdout.flush()

        hilo = threading.Thread(target=lector, daemon=True)
        hilo.start()
        try:
            for linea in sys.stdin:
                c.s.sendall(linea.encode())
        except (KeyboardInterrupt, EOFError):
            pass
        except OSError:
            pass
        time.sleep(1.2)          # dejar que el hilo volque lo que quede
        c.close()
        return 0

    if not args:
        print("[*] conectado. Usa: cam.py 'comando' ...")
        c.close()
        return 0

    for cmd in args:
        try:
            c.run(cmd)
        except ConnectionError:
            print("[!] la conexion se corto (posible reinicio del vigilante)")
            return 2
    c.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
