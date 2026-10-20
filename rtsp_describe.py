#!/usr/bin/env python3
"""
rtsp_describe.py — prueba rutas RTSP a pelo y dice cuales devuelven medios.

No usa ffprobe: habla RTSP directamente (OPTIONS + DESCRIBE) y mira el SDP.
Asi se ve la diferencia entre "el servidor contesta pero sin stream" y
"esta ruta si trae video".

Uso:
    ./rtsp_describe.py [IP] [PUERTO]
"""
import socket
import sys

IP = sys.argv[1] if len(sys.argv) > 1 else "10.77.0.17"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 554

RUTAS = [
    "screenlive",
    "screenlive/",
    "screenlive/0",
    "screenlive/1",
    "streamtype=0",
    "streamtype=1",
    "live",
    "live/0",
    "live/ch00_0",
    "live/ch00_1",
    "video",
    "video0",
    "main",
    "sub",
    "stream0",
    "stream1",
    "0",
    "1",
    "11",
    "12",
    "av0_0",
    "av0_1",
    "cam/realmonitor?channel=1&subtype=0",
    "onvif1",
    "onvif2",
    "h264",
    "h265",
    "profile1",
    "profile2",
    "media",
    "rtsp",
    "",
]


def describe(url, cseq=1):
    try:
        s = socket.create_connection((IP, PORT), timeout=5)
    except OSError as e:
        return None, f"conexion fallida: {e}"
    try:
        req = (
            f"DESCRIBE {url} RTSP/1.0\r\n"
            f"CSeq: {cseq}\r\n"
            "Accept: application/sdp\r\n"
            "User-Agent: probe\r\n\r\n"
        )
        s.sendall(req.encode())
        s.settimeout(5)
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"Content-Length" in data:
                cab, _, resto = data.partition(b"\r\n\r\n")
                import re
                m = re.search(rb"Content-Length:\s*(\d+)", cab, re.I)
                if m and len(resto) >= int(m.group(1)):
                    break
        return data.decode("utf-8", "replace"), None
    except OSError as e:
        return None, str(e)
    finally:
        s.close()


def resumen(resp):
    """(codigo, tiene_medios, codecs, control)"""
    if not resp:
        return None
    primera = resp.split("\r\n", 1)[0]
    codigo = primera.split(" ")[1] if " " in primera else "?"
    tiene_v = "\r\nm=video" in resp or resp.startswith("m=video")
    codecs = []
    for linea in resp.splitlines():
        if linea.startswith("a=rtpmap:"):
            codecs.append(linea.split(" ", 1)[-1])
    controles = [l.split(":", 1)[1] for l in resp.splitlines() if l.startswith("a=control:")]
    return codigo, tiene_v, codecs, controles


print(f"=== sondeo RTSP a {IP}:{PORT} ===")
print(f"{'ruta':38s} {'cod':5s} medios  codecs")
print("-" * 90)

con_medios = []
for r in RUTAS:
    url = f"rtsp://{IP}:{PORT}/{r}" if r != "" else f"rtsp://{IP}:{PORT}/"
    resp, err = describe(url)
    if err:
        print(f"{r or '(vacio)':38s} --    {err[:40]}")
        continue
    cod, tiene_v, codecs, controles = resumen(resp)
    marca = "SI" if tiene_v else "no"
    print(f"{r or '(vacio)':38s} {cod:5s} {marca:6s} {', '.join(codecs)[:40]}")
    if tiene_v:
        con_medios.append((url, resp))

print()
if con_medios:
    url, resp = con_medios[0]
    print(f"=== RUTA CON MEDIOS: {url} ===")
    print(resp[:1500])
    print()
    print(f"Reproducir: ffplay -rtsp_transport tcp '{url}'")
else:
    print("=== ninguna ruta devolvio medios ===")
    print("  El servidor RTSP responde pero no tiene stream asociado.")
    print("  Siguiente paso: mirar por que (encoder no adjunto / otro interruptor).")
