# De Panchen a Root

## La historia detrás del proyecto

Panchen es solo uno de los muchos nombres de las tiendas chinas de descuentos que se encuentran repartidas por todo México. Estas tiendas suelen vender **todo tipo de productos a precios sorprendentemente bajos**.

<p align="center">
  <img src="pics/1.jpg" alt="Tienda Panchen" width="55%">
</p>

Recientemente, abrió una nueva tienda Panchen cerca de mi casa, así que decidí pasar a echar un vistazo. Mientras recorría la sección de electrónica, me encontré con una de esas **cámaras IP baratas y de calidad cuestionable**: el tipo de dispositivo que te hace preguntarte qué estará funcionando realmente en su interior.

<p align="center">
  <img src="pics/2.jpg" alt="Cámara IP" width="55%">
</p>

Ese pequeño descubrimiento despertó mi curiosidad y **marcó el inicio de este proyecto**. Así que compré una de esas cámaras y **me puse manos a la obra**.

## Conociendo la cámara

Después de abrir la cámara, identifiqué los puertos UART y un chip que, muy probablemente, contiene el firmware.

<p align="center">
  <img src="pics/3.jpg" alt="Puertos UART" width="55%">
</p>

<p align="center">
  <img src="pics/4.jpg" alt="Chip de memoria" width="55%">
</p>

Mi primera idea fue soldar cables a los puertos UART para ver qué podía obtener a través de la consola serie. Por desgracia, U-Boot estaba protegido por contraseña y ninguna de las contraseñas predeterminadas que probé funcionó.

<p align="center">
  <img src="pics/5.jpg" alt="Consola U-Boot" width="55%">
</p>

```text
U-Boot 2014.04 (May 10 2024 - 14:52:35)

CPU: XM533W1
DRAM:  64 MiB
MMC:   arasan: 0
In:    serial
Out:   serial
Err:   serial
Net:   PHY id1 ffff id2 ffff Phy not found
dwmac.10010000
Press Ctrl+C to stop autoboot
Password: 

Password: ****
Sorry, please try again!
Password: ****
Sorry, please try again!
Password: *****
```

La siguiente opción fue intentar leer directamente el chip de memoria utilizando una pinza SPI y un programador CH341A.

<p align="center">
  <img src="pics/7.jpg" alt="chip" width="55%">
</p>

<p align="center">
  <img src="pics/6.jpg" alt="ch341a" width="55%">
</p>

Esta etapa resultó bastante frustrante. Después de varios intentos de lectura, `flashrom` siempre devolvía el mismo error:

```text
flashrom v1.8.0 (git:v1.8.0) on Linux 6.18.55-1-lts (x86_64)
flashrom is free software, get the source code at https://flashrom.org

No EEPROM/flash device found.
Note: flashrom can never write if the flash chip isn't found automatically.
```

Después de varios intentos fallidos, decidí automatizar el proceso mediante un bucle `while` para ejecutar lecturas de forma continua, registrar la fecha y hora de cada intento y observar los resultados en tiempo real:

```bash
while true; do
    fecha=$(date '+%Y%m%d_%H%M%S')
    echo "===== Inicio: $fecha ====="
    sudo flashrom -p ch341a_spi -r "woox_firmware_${fecha}.bin" 2>&1
    sleep 1
done
```

Mientras el proceso se ejecutaba, probé a ajustar cuidadosamente la presión sobre la pinza y a mejorar el contacto entre sus pines y los terminales del chip.

Después de tantos intentos, **¡voilà!** Finalmente, conseguí que `flashrom` detectara el chip y realizara la primera lectura.

<p align="center">
  <img src="pics/9.jpg" alt="volcado" width="55%">
</p>

¡Por fin, una señal de progreso! Después de luchar con la conexión física y repetir el proceso una y otra vez, había conseguido dar el primer paso para extraer el firmware de la cámara.
