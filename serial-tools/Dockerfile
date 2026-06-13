FROM balenalib/raspberrypi3-64-debian:bookworm-run

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        minicom \
        picocom \
        python3 \
        python3-pip \
        ttyd \
        usbutils \
        wget \
    && python3 -m pip install --no-cache-dir --break-system-packages \
        esptool \
        pyserial \
    && mkdir -p /data \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /data

EXPOSE 7681

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
