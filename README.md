# Balena MeshCore Browser Flasher

[![Deploy with balena](https://www.balena.io/deploy.png)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/VorasLT/nebra)

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

Builds a custom lightweight Chromium remote UI for ARM64/aarch64. It uses:

```text
Chromium + Xvfb + Openbox + x11vnc + noVNC/websockify
```

This is intentionally smaller and simpler than the previous LinuxServer/Selkies browser image, which was too heavy on Raspberry Pi 3 / Nebra hardware and could repeatedly crash or stall.

It starts Chromium with a blank page. After the remote browser UI has loaded, manually open:

```text
https://flasher.meshcore.co.uk/
```

The startup command keeps WebSerial/WebUSB enabled but uses `about:blank` as the initial page.

The service is privileged and uses Balena sysfs/procfs/kernel-module labels so it can see host USB and serial devices where BalenaOS permits it.

The custom noVNC endpoint is exposed over HTTPS:

```text
https://<device-ip>:3001/
```

The noVNC session uses the `PASSWORD` value from `docker-compose.yml`. VNC authentication commonly uses only the first 8 password characters, so the default is `changeme`. Change it before deployment.

`shm_size: "1gb"` is included to make Chromium more stable. If a specific Balena builder or Compose parser rejects `shm_size`, remove that line and redeploy.

For Raspberry Pi 3 class hardware, the Chromium service is intentionally tuned for low load:

```text
1024x768 resolution
16-bit Xvfb display
minimal Openbox window manager
local x11vnc only, proxied through websockify/noVNC
no Selkies, gamepad interposer, nested Docker, audio, microphone, or clipboard sync
Chromium single-process/no-zygote mode to reduce renderer process churn
```

If the UI is still too slow, use `serial-tools` and `esptool.py` as the reliable fallback path.

### serial-tools

Builds a small ARM64 diagnostic container with:

```text
python3 python3-pip usbutils picocom minicom ca-certificates curl wget bash ttyd
```

`ttyd` is installed from the pinned upstream ARM64 release binary instead of `apt`, because some Debian/Balena package repositories do not provide a `ttyd` package for this base image.

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
8. Manually open `https://flasher.meshcore.co.uk/`.
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
3. Change `PASSWORD=changeme` in `docker-compose.yml` before deployment.
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

### Raspberry Pi 3 may still be slow with Chromium/noVNC

The Raspberry Pi 3 Compute Module class hardware is limited for remote Chromium workloads. This project uses a lighter custom stack:

```text
Xvfb + Openbox + x11vnc + noVNC/websockify
```

It also runs Chromium with `--single-process`, `--no-zygote`, and `--renderer-process-limit=1`. This is less elegant than normal Chromium process isolation, but it reduces process churn and memory pressure on very small hardware.

If it is still almost unusable, the hardware is likely the bottleneck. Use the web terminal at `http://<device-ip>:7681/` and flash with `esptool.py` instead.

### Chromium OOM score log lines

Logs like this usually mean a Chromium renderer process exited before Chromium could adjust its Linux OOM score:

```text
Failed to adjust OOM score of renderer with pid ...: No such file or directory
```

The project reduces this by running Chromium in single-process/no-zygote mode. If the web UI still crashes, the device is probably running out of CPU or RAM for remote Chromium, and `serial-tools` with `esptool.py` is the more reliable fallback.

### Chromium profile appears to be in use

If Chromium crashes, the persistent `/config/chromium` profile can keep stale lock files:

```text
The profile appears to be in use by another Chromium process
Chromium has locked the profile
```

The startup script removes these stale files before launching Chromium:

```text
SingletonCookie
SingletonLock
SingletonSocket
DevToolsActivePort
```

If the error still appears, restart the `chromium-flasher` service from the Balena Dashboard. As a last resort, remove the `chromium-config` volume to force a clean Chromium profile.

### DBus socket log lines

Chromium may log DBus errors in small containers:

```text
Failed to connect to socket /run/dbus/system_bus_socket
Could not parse server address
```

The custom `chromium-flasher` startup script now starts a minimal DBus system bus and session bus before Chromium. Occasional DBus warnings are usually not fatal, but repeated DBus setup failures can make Chromium noisier and less predictable.

The session bus is started with an explicit address:

```text
unix:path=/tmp/dbus-session-bus
```

### GCM quota exceeded log lines

Chromium may try to initialize Google Cloud Messaging or push notification internals even when this project only needs one flasher page:

```text
google_apis/gcm/engine/registration_request.cc
Registration response error message: QUOTA_EXCEEDED
```

The startup script removes stale Chromium GCM profile state, and Chromium starts with push/GCM/background Google services disabled. These log lines are not directly related to WebSerial/WebUSB.

### Missing X server or DISPLAY

If Chromium exits with:

```text
Missing X server or $DISPLAY
The platform failed to initialize
```

the browser started before the virtual X server was ready, or a stale X lock file was left behind after a crash. The startup script now removes stale X lock files, starts Xvfb, and waits for `xdpyinfo` to confirm the display is available before launching Chromium.

### Architecture mismatch: arm64 vs armv7/armhf

This project targets ARM64/aarch64:

```yaml
build:
  context: ./chromium-flasher
```

and:

```dockerfile
FROM balenalib/raspberrypi3-64-debian:bookworm-run
```

If your BalenaOS application is 32-bit ARM instead, adapt both service images:

1. Replace the `chromium-flasher` base image with a matching Balena base, for example a `raspberrypi3-debian` / armv7 variant.
2. Replace the serial-tools base image with a matching Balena base, for example a `raspberrypi3-debian` / armv7 variant.
3. Confirm Debian provides a compatible `chromium` package for that architecture.
4. In `serial-tools/Dockerfile`, replace the `ttyd.aarch64` download with the matching upstream asset, usually `ttyd.armhf` for armhf or `ttyd.arm` where appropriate.
5. Rebuild the Balena release for the correct device type.

If deploy fails with an architecture error, confirm the Balena application device type and whether the OS image is 64-bit or 32-bit.
