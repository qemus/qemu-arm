# syntax=docker/dockerfile:1

ARG VERSION_ARG="latest"

FROM qemux/fiano AS tool
FROM qemux/qemu:${VERSION_ARG} AS src
FROM debian:trixie-slim

ARG VERSION_ARG="0.0"
ARG VERSION_VNC="1.6.0"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        bc \
        jq \
        xxd \
        tini \
        wget \
        7zip \
        curl \
        fdisk \
        nginx \
        procps \
        ethtool \
        seabios \
        iptables \
        iproute2 \
        apt-utils \
        dnsmasq \
        xz-utils \
        net-tools \
        e2fsprogs \
        qemu-utils \
        iputils-ping \
        genisoimage \
        netcat-openbsd \
        ca-certificates \
        qemu-system-arm \
        qemu-efi-aarch64 && \
    apt-get clean && \
    mkdir -p /etc/qemu && \
    echo "allow br0" > /etc/qemu/bridge.conf && \
    mkdir -p /usr/share/novnc && \
    wget "https://github.com/novnc/noVNC/archive/refs/heads/master.tar.gz" -O /tmp/novnc.tar.gz -q --timeout=10 && \
    tar -xf /tmp/novnc.tar.gz -C /tmp/ && \
    cd "/tmp/noVNC-master" && \
    mv app core vendor package.json *.html /usr/share/novnc && \
    unlink /etc/nginx/sites-enabled/default && \
    sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf && \
    echo "$VERSION_ARG" > /run/version && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=src /run/*.sh /run/
COPY --from=src /var/www /var/www
COPY --from=tool /utk.bin /run/
COPY --from=src /usr/share/novnc /usr/share/novnc
COPY --from=src /etc/nginx/default.conf /etc/nginx/default.conf

COPY --chmod=755 ./src /run/

VOLUME /storage
EXPOSE 22 5900 8006

ENV BOOT="alpine"
ENV CPU_CORES="2"
ENV RAM_SIZE="2G"
ENV DISK_SIZE="64G"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
