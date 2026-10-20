
# From Panchen to Full Firmware

## The Story Behind the Project

Panchen is just a random name among the many Chinese discount stores scattered across Mexico. These stores typically sell **all kinds of products at remarkably low prices**.

<p align="center">
  <img src="pics/1.jpg" alt="Boot" width="55%">
</p>

Recently, a new Panchen store opened near my home, so I decided to stop by and take a look around. While browsing the electronics section, I came across one of those **cheap, questionable-quality IP cameras** — the kind of device that makes you wonder what's actually running under the hood.


<p align="center">
  <img src="pics/2.jpg" alt="Boot" width="55%">
</p>

That little discovery sparked my curiosity and **set the stage for this project.**. So, I bought one of those cameras and **got to work.**


## Getting to Know the Camera

After opening the camera, I identified the UART ports and a chip that most likely contains the firmware.

<p align="center">
  <img src="pics/3.jpg" alt="Boot" width="55%">
</p>

<p align="center">
  <img src="pics/4.jpg" alt="Boot" width="55%">
</p>

My first idea was to solder wires to the UART ports and see what I could get out of the serial console. Unfortunately, U-Boot was password-protected, and none of the default passwords I tried worked.

<p align="center">
  <img src="pics/5.jpg" alt="Boot" width="55%">
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
