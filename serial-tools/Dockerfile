FROM balenalib/raspberrypi3-64-debian:bookworm-run

ENV DEBIAN_FRONTEND=noninteractive
ENV TTYD_VERSION=1.7.7

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        minicom \
        picocom \
        python3 \
        python3-pip \
        usbutils \
        wget \
    && curl -fsSL \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.aarch64" \
        -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd \
    && python3 -m pip install --no-cache-dir --break-system-packages \
        esptool \
        pyserial \
        pytap2 \
        meshtastic \
        meshcore-cli \
    && mkdir -p /data \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /data

EXPOSE 7681

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
