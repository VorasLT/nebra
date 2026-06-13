# Balena MeshCore Browser Flasher

Clean BalenaOS multi-container project for one job: run a LAN-accessible Chromium browser on a Balena device so a USB-connected Heltec V3 / ESP32-S3 MeshCore device can be flashed through WebSerial/WebUSB.

This project intentionally does not include any old Nebra miner, Helium, packet-forwarder, diagnostics, gatewayrs, or gateway services.

## Architecture diagram

```text
PC browser
  -> Chromium web UI/noVNC
  -> Chromium inside Balena container
  -> WebSerial/WebUSB
  -> Heltec V3 USB
```

Your PC only views the remote Chromium session. The actual Chromium process runs inside the BalenaOS device, so WebSerial/WebUSB talks to the USB device attached to the Balena device, not to your PC.

## Expected URLs

```text
Chromium:     https://<device-ip>:3001/
Serial tools: http://<device-ip>:7681/
```

The Chromium container uses HTTPS on port 3001. A browser certificate warning is expected because the container normally uses a self-signed certificate.

## Services

### chromium-flasher

Uses `lscr.io/linuxserver/chromium:arm64v8-latest` for a browser UI reachable from your LAN.

It starts Chromium with:

```text
--no-sandbox --disable-dev-shm-usage --enable-features=WebSerial,WebUSB https://flasher.meshcore.co.uk/
```

The service is privileged and uses Balena sysfs/procfs/kernel-module labels so it can see host USB and serial devices where BalenaOS permits it.

The LinuxServer Chromium image may also expose HTTP on port 3000, but this project maps only the primary HTTPS endpoint:

```text
https://<device-ip>:3001/
```

`shm_size: "1gb"` is included to make Chromium more stable. If a specific Balena builder or Compose parser rejects `shm_size`, remove that line and redeploy.

### serial-tools

Builds a small ARM64 diagnostic container with:

```text
python3 python3-pip usbutils picocom minicom ca-certificates curl wget bash ttyd
```

Python packages:

```text
esptool pyserial
```

The terminal runs through ttyd:

```text
http://<device-ip>:7681/
```

The persistent `/data` volume is available for firmware files if you use `esptool.py` as a fallback.

## Deploy to Balena

Create a new Balena application for the target device type and push this project as a clean release.

Using the Balena CLI:

```bash
balena login
balena push <your-balena-app-name>
```

Using GitHub integration:

1. Push this repository to GitHub.
2. Connect the repository to your Balena application in the Balena Dashboard.
3. Let Balena build and release the project.

This project is intended for Raspberry Pi 3 Compute Module / Nebra Indoor Miner hardware running BalenaOS with an ARM64/aarch64 userspace.

## First test checklist

1. Deploy project to Balena.
2. Open serial-tools terminal.
3. Run `lsusb`.
4. Run `ls -l /dev/ttyUSB* /dev/ttyACM*`.
5. Run `esptool.py --port /dev/ttyUSB0 chip_id`.
6. If needed, try `/dev/ttyACM0` instead.
7. Open Chromium web UI.
8. Open MeshCore flasher.
9. Try Connect/Flash.

## Serial test commands

List USB devices:

```bash
lsusb
```

List serial devices:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM*
```

Check ESP32-S3 chip ID:

```bash
esptool.py --port /dev/ttyUSB0 chip_id
```

Or, if the board appears as ACM:

```bash
esptool.py --port /dev/ttyACM0 chip_id
```

Open a serial console:

```bash
picocom -b 115200 /dev/ttyUSB0
```

Exit `picocom` with `Ctrl+A`, then `Ctrl+X`.

## Fallback flashing with esptool

If the browser flasher is not usable, you can copy firmware into the `serial-tools` `/data` volume and flash with `esptool.py`.

Example:

```bash
esptool.py --chip esp32s3 --port /dev/ttyUSB0 --baud 460800 write_flash 0x0 firmware.bin
```

Important: the flash offset and command layout depend on the firmware format and the firmware provider's instructions. Do not treat `0x0` as a universal offset for every MeshCore or Heltec firmware package.

## Security

Both containers use:

```yaml
privileged: true
```

This is intentional so Chromium and the serial tools can access USB/serial devices through BalenaOS, but it increases risk.

Security rules:

1. Do not expose ports `3001` or `7681` to the internet.
2. Use this only on a trusted LAN or VPN.
3. Change `PASSWORD=change_me` in `docker-compose.yml` before deployment.
4. Treat the ttyd terminal as shell access to a privileged container.

## Troubleshooting

### Chromium opens but MeshCore flasher does not see the device

Check the device from the serial-tools terminal:

```bash
lsusb
ls -l /dev/ttyUSB* /dev/ttyACM*
```

Also check:

1. The USB cable must support data, not only charging.
2. The Heltec V3 / ESP32-S3 may need BOOT/RESET timing for flash mode.
3. `chromium-flasher` must be running with `privileged: true`.
4. The device may appear as `/dev/ttyACM0` instead of `/dev/ttyUSB0`.

### esptool sees the device but WebSerial does not

This usually points to Chromium/WebSerial permissions or browser state.

Try:

1. Reload or reopen `https://flasher.meshcore.co.uk/` inside the remote Chromium session.
2. Try the other serial device if both `/dev/ttyUSB0` and `/dev/ttyACM0` exist.
3. Confirm Chromium was started with `--enable-features=WebSerial,WebUSB`.
4. Restart the `chromium-flasher` service from the Balena Dashboard.

### /dev/ttyUSB0 is missing but /dev/ttyACM0 exists

Use the port that actually appears on the device:

```bash
esptool.py --port /dev/ttyACM0 chip_id
picocom -b 115200 /dev/ttyACM0
```

Different USB serial chips and ESP32-S3 USB modes expose different device names.

### USB cable might be charge-only

If `lsusb` does not change when you plug the Heltec in, try another cable. Many USB cables power the board but do not carry data.

### BOOT/RESET might be needed

Some ESP32-S3 boards need BOOT held while pressing RESET, or similar timing, before flashing. Follow the Heltec or MeshCore firmware instructions for the exact button sequence.

### Raspberry Pi 3 may be slow with Chromium/noVNC

The Raspberry Pi 3 Compute Module class hardware is limited for remote Chromium/noVNC workloads. The UI may feel slow, but it should be adequate for opening the flasher and running a firmware flash.

### Architecture mismatch: arm64 vs armv7/armhf

This project targets ARM64/aarch64:

```yaml
image: lscr.io/linuxserver/chromium:arm64v8-latest
```

and:

```dockerfile
FROM balenalib/raspberrypi3-64-debian:bookworm-run
```

If your BalenaOS application is 32-bit ARM instead, adapt both service images:

1. Replace the Chromium image with a compatible 32-bit ARM variant if LinuxServer publishes one for your target, or build a custom Chromium container.
2. Replace the serial-tools base image with a matching Balena base, for example a `raspberrypi3-debian` / armv7 variant.
3. Rebuild the Balena release for the correct device type.

If deploy fails with an architecture error, confirm the Balena application device type and whether the OS image is 64-bit or 32-bit.
