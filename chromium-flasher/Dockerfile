FROM balenalib/raspberrypi3-64-debian:bookworm-run

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        chromium \
        dbus \
        dbus-x11 \
        fonts-dejavu-core \
        fonts-liberation \
        novnc \
        openbox \
        openssl \
        procps \
        websockify \
        wget \
        x11vnc \
        xauth \
        xvfb \
    && mkdir -p /config /opt/chromium-flasher \
    && printf '%s\n' \
        '<!doctype html>' \
        '<meta http-equiv="refresh" content="0; url=/vnc.html?autoconnect=1&resize=remote">' \
        '<a href="/vnc.html?autoconnect=1&resize=remote">Open Chromium flasher</a>' \
        > /usr/share/novnc/index.html \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start-chromium-flasher
RUN chmod +x /usr/local/bin/start-chromium-flasher

EXPOSE 3001

CMD ["/usr/local/bin/start-chromium-flasher"]
