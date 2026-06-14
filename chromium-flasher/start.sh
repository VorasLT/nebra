#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"

DISPLAY_WIDTH="${DISPLAY_WIDTH:-1024}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-768}"
DISPLAY_DEPTH="${DISPLAY_DEPTH:-16}"
PASSWORD="${PASSWORD:-changeme}"
START_URL="${START_URL:-about:blank}"
CHROME_CLI="${CHROME_CLI:---no-sandbox --no-zygote --single-process --renderer-process-limit=1 --process-per-site --disable-site-isolation-trials --disable-dev-shm-usage --enable-features=WebSerial,WebUSB --disable-gpu --disable-software-rasterizer --no-proxy-server --proxy-server=direct:// --proxy-bypass-list=* --disable-background-networking --disable-sync --disable-extensions --disable-component-update --disable-default-apps --disable-popup-blocking --disable-translate --disable-notifications --disable-push-messaging --disable-gcm --disable-domain-reliability --disable-client-side-phishing-detection --disable-crash-reporter --disable-breakpad --metrics-recording-only --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-features=Translate,BackForwardCache,MediaRouter,OptimizationHints,AutofillServerCommunication,InterestFeedContentSuggestions,PushMessaging,NotificationTriggers,BatteryStatus --no-first-run --start-maximized --window-size=${DISPLAY_WIDTH},${DISPLAY_HEIGHT} --ozone-platform=x11 ${START_URL}}"

mkdir -p /config/chromium /config/certs "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

DISPLAY_NUM="${DISPLAY#:}"

mkdir -p /run/dbus
rm -f /run/dbus/pid /run/dbus/system_bus_socket
dbus-daemon --system --fork --nopidfile >/tmp/dbus-system.log 2>&1 || true

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/tmp/dbus-session-bus}"
rm -f /tmp/dbus-session-bus
if [ ! -S /tmp/dbus-session-bus ]; then
    dbus-daemon \
        --session \
        --fork \
        --address="${DBUS_SESSION_BUS_ADDRESS}" \
        >/tmp/dbus-session.log 2>&1 || true
fi

rm -f \
    /config/chromium/SingletonCookie \
    /config/chromium/SingletonLock \
    /config/chromium/SingletonSocket \
    /config/chromium/DevToolsActivePort

rm -rf \
    "/config/chromium/Default/GCM Store" \
    "/config/chromium/GCM Store"

for host in \
    mtalk.google.com \
    android.clients.google.com \
    fcmregistrations.googleapis.com \
    firebaseinstallations.googleapis.com; do
    if ! grep -q "[[:space:]]${host}$" /etc/hosts; then
        printf '0.0.0.0 %s\n' "${host}" >> /etc/hosts
    fi
done

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

CERT_FILE="/config/certs/novnc.pem"
if [ ! -s "${CERT_FILE}" ]; then
    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -keyout /tmp/novnc.key \
        -out /tmp/novnc.crt \
        -days 3650 \
        -subj "/CN=balena-chromium-flasher"
    cat /tmp/novnc.key /tmp/novnc.crt > "${CERT_FILE}"
    rm -f /tmp/novnc.key /tmp/novnc.crt
fi

Xvfb "${DISPLAY}" \
    -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" \
    -nolisten tcp \
    -ac &
XVFB_PID=$!

for _ in $(seq 1 40); do
    if xdpyinfo -display "${DISPLAY}" >/tmp/xdpyinfo.log 2>&1; then
        break
    fi

    if ! kill -0 "${XVFB_PID}" 2>/dev/null; then
        echo "Xvfb exited before display ${DISPLAY} became available" >&2
        cat /tmp/xdpyinfo.log >&2 || true
        exit 1
    fi

    sleep 0.25
done

if ! xdpyinfo -display "${DISPLAY}" >/tmp/xdpyinfo.log 2>&1; then
    echo "Timed out waiting for X display ${DISPLAY}" >&2
    cat /tmp/xdpyinfo.log >&2 || true
    exit 1
fi

openbox >/tmp/openbox.log 2>&1 &
OPENBOX_PID=$!

x11vnc \
    -display "${DISPLAY}" \
    -rfbport 5900 \
    -localhost \
    -forever \
    -shared \
    -passwd "${PASSWORD}" \
    -xkb \
    -noxdamage \
    -repeat \
    -quiet &
X11VNC_PID=$!

websockify \
    --web=/usr/share/novnc \
    --cert="${CERT_FILE}" \
    3001 \
    localhost:5900 &
WEBSOCKIFY_PID=$!

sleep 2

chromium \
    --user-data-dir=/config/chromium \
    ${CHROME_CLI} &
CHROMIUM_PID=$!

trap 'kill ${CHROMIUM_PID} ${WEBSOCKIFY_PID} ${X11VNC_PID} ${OPENBOX_PID} ${XVFB_PID} 2>/dev/null || true' EXIT
wait "${CHROMIUM_PID}"
