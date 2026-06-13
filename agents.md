Sukurk pilną naują GitHub/Balena projektą, dedikuotą tik vienam tikslui: BalenaOS įrenginyje paleisti naršyklę, per kurią būtų galima naudoti WebSerial/WebUSB firmware flashinimui USB prijungtam Heltec V3 / ESP32-S3 MeshCore įrenginiui.

Kontekstas:

* Įrenginys: Raspberry Pi 3 Compute Module / Nebra Indoor Miner aparatinė platforma.
* OS: BalenaOS.
* Architektūra: arm64/aarch64, bet projekte palik komentarus, kaip adaptuoti armv7/armhf, jei reikėtų.
* Prie USB prijungtas Heltec V3 / ESP32-S3 MeshCore siųstuvas.
* Tikslas: iš mano kompiuterio lokaliame tinkle atsidaryti web sąsają, kurioje matyčiau Balena įrenginyje veikiančią Chromium naršyklę. Toje Chromium naršyklėje turiu galėti atsidaryti https://flasher.meshcore.co.uk/ ir naudoti WebSerial/WebUSB su USB įrenginiu, prijungtu prie Balena įrenginio, o ne prie mano kompiuterio.
* Ignoruok bet kokią seną Nebra miner / Helium / packet-forwarder / diagnostics / gatewayrs konfigūraciją. Projektas turi būti visiškai naujas ir dedikuotas tik naršyklei, WebSerial/WebUSB flashinimui ir serial diagnostikai.

Sukurk tokį projektą:

1. Failų struktūra:

   * docker-compose.yml
   * README.md
   * .gitignore
   * serial-tools/Dockerfile
   * serial-tools/start.sh, jei reikia
   * papildomi config failai, jei reikia

2. docker-compose.yml reikalavimai:

   * Naudok compose versiją, suderinamą su Balena multi-container projektu, pvz. version: "2.4".

   * Turi būti bent du servisai:
     a) chromium-flasher
     b) serial-tools

   * chromium-flasher:

     * Turi paleisti web pasiekiamą Chromium naršyklę.
     * Pageidautina naudoti jau paruoštą image: lscr.io/linuxserver/chromium:arm64v8-latest, jei jis tinkamas BalenaOS arm64.
     * Jei manai, kad geriau kurti custom image, pagrįsk README faile ir pateik Dockerfile.
     * Web prieiga turi būti per lokalaus tinklo URL, pvz. https://BALENA-IP:3001/
     * Chromium turi startuoti su https://flasher.meshcore.co.uk/
     * Chromium turi būti paleidžiamas su parametrais:
       --no-sandbox
       --disable-dev-shm-usage
       --enable-features=WebSerial,WebUSB
     * Turi būti privileged: true, kad konteineris matytų USB/serial įrenginius.
     * Pridėk Balena labels:
       io.balena.features.sysfs: "1"
       io.balena.features.procfs: "1"
       io.balena.features.kernel-modules: "1"
     * Pridėk persistent volume Chromium config’ui, pvz. chromium-config:/config
     * Pridėk environment:
       TZ=Europe/Vilnius
       CUSTOM_USER=admin
       PASSWORD=change_me
       PUID=0
       PGID=0
       CHROME_CLI su reikiamais Chromium argumentais ir MeshCore flasher URL.
     * Portas:
       3001:3001
     * Jei image palaiko ir 3000/http, palik komentarą, bet pagrindinis turi būti 3001/https.

   * serial-tools:

     * Lengvas diagnostikos/fallback konteineris su web terminalu.
     * Turi turėti ttyd, esptool, pyserial, usbutils, picocom, minicom.
     * Turi būti privileged: true.
     * Pridėk tuos pačius Balena labels:
       io.balena.features.sysfs: "1"
       io.balena.features.procfs: "1"
       io.balena.features.kernel-modules: "1"
     * Web terminalas turi būti pasiekiamas per:
       http://BALENA-IP:7681/
     * Start komanda turi paleisti ttyd:
       ttyd -W -p 7681 bash
     * Portas:
       7681:7681
     * Turi būti persistent volume /data, kur galėčiau įsidėti firmware failus, jei naudočiau esptool.

3. README.md turi aiškiai paaiškinti:

   * Projekto paskirtį.
   * Kaip deployinti į Balena:

     * su balena push
     * arba per GitHub integration / Balena Dashboard release.
   * Kaip prisijungti prie Chromium:
     https://BALENA-IP:3001/
   * Kad sertifikato perspėjimas yra tikėtinas dėl self-signed HTTPS.
   * Kaip prisijungti prie terminalo:
     http://BALENA-IP:7681/
   * Kaip patikrinti, ar Heltec matomas:
     lsusb
     ls -l /dev/ttyUSB* /dev/ttyACM*
   * Kaip patikrinti ESP32-S3:
     esptool.py --port /dev/ttyUSB0 chip_id
     arba
     esptool.py --port /dev/ttyACM0 chip_id
   * Kaip naudoti picocom:
     picocom -b 115200 /dev/ttyUSB0
   * Kaip naudoti esptool kaip fallback firmware flashinimui:
     esptool.py --chip esp32s3 --port /dev/ttyUSB0 --baud 460800 write_flash 0x0 firmware.bin
     Bet README turi perspėti, kad konkretus flash offset gali priklausyti nuo firmware formato ir gamintojo instrukcijos. Nepateik vieno offset kaip universaliai teisingo.
   * Paaiškink, kad WebSerial/WebUSB veiks su USB įrenginiu, prijungtu prie Balena įrenginio, nes Chromium realiai veikia konteineryje ant BalenaOS.
   * Paaiškink, kad šio nereikia atidaryti į internetą.
   * Aiškiai įrašyk saugumo perspėjimą:

     * chromium-flasher ir serial-tools naudoja privileged: true;
     * portai 3001 ir 7681 turi būti pasiekiami tik LAN/VPN;
     * būtina pakeisti PASSWORD reikšmę.
   * Troubleshooting skyrius:
     a) Chromium atsidaro, bet MeshCore flasher nemato įrenginio.

     * Tikrinti serial-tools terminale lsusb ir /dev/ttyUSB* /dev/ttyACM*.
     * Patikrinti USB kabelį, ar jis data kabelis.
     * Patikrinti BOOT/RESET režimą.
     * Patikrinti, ar konteineris privileged.
       b) esptool mato įrenginį, bet web flasher ne.
     * Tikėtina problema Chromium/WebSerial leidimuose.
     * Pabandyti atidaryti flasher puslapį iš naujo.
     * Pabandyti kitą serial portą.
     * Patikrinti, ar Chromium startavo su WebSerial/WebUSB features.
       c) Balena deploy nepavyksta dėl architektūros.
     * Pateik ką keisti iš arm64 į armv7/armhf.
       d) Chromium veikia labai lėtai.
     * Paaiškink, kad RPi3 silpnas Chromium/noVNC scenarijui, bet firmware flashinimui turėtų pakakti.
       e) /dev/ttyUSB0 nėra, bet yra /dev/ttyACM0.
     * Paaiškink, kad reikia naudoti tą portą, kuris realiai atsirado.

4. serial-tools/Dockerfile:

   * Naudok arm64 suderinamą bazę, pvz. balenalib/raspberrypi3-64-debian:bookworm-run arba arm64v8/debian:bookworm-slim.
   * Įdiek:
     python3
     python3-pip
     usbutils
     picocom
     minicom
     ca-certificates
     curl
     wget
     bash
     ttyd
   * Per pip įdiek:
     esptool
     pyserial
   * Jei Debian bookworm reikalauja --break-system-packages, naudok jį.
   * Sukurk /data katalogą.
   * EXPOSE 7681.
   * CMD turi paleisti ttyd.

5. Pateik galutinį docker-compose.yml, kuris būtų realiai paruoštas deployinti į Balena kaip naujas projektas.

6. Neįtrauk jokios Nebra miner, Helium, diagnostics, packet-forwarder, gatewayrs ar senos konfigūracijos.

7. Papildomai:

   * Pridėk README skyrių “Expected URLs”:

     * Chromium: https://<device-ip>:3001/
     * Serial tools: http://<device-ip>:7681/
   * Pridėk README skyrių “First test checklist”:

     1. Deploy project to Balena.
     2. Open serial-tools terminal.
     3. Run lsusb.
     4. Run ls -l /dev/ttyUSB* /dev/ttyACM*.
     5. Run esptool.py chip_id.
     6. Open Chromium web UI.
     7. Open MeshCore flasher.
     8. Try Connect/Flash.
   * Pridėk README skyrių “Security”.
   * Pridėk README skyrių “Architecture diagram” su ASCII schema:
     PC browser -> Chromium web UI/noVNC -> Chromium inside Balena container -> WebSerial/WebUSB -> Heltec V3 USB.

8. Atsakydamas pateik visų failų turinį atskirais markdown code block’ais su failų keliais.
