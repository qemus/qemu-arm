FROM debian:trixie-slim

ARG VERSION_VNC="1.6.0"
ARG VERSION_ARG="latest"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        bc \
        jq \
        tini \
        wget \
        7zip \
        curl \
        nginx \
        procps \
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
        ca-certificates \
        netcat-openbsd \
        qemu-system-arm \
        qemu-efi-aarch64 && \
    apt-get clean && \
    mkdir -p /etc/qemu && \
    echo "allow br0" > /etc/qemu/bridge.conf && \
    mkdir -p /usr/share/novnc && \
    wget "https://github.com/novnc/noVNC/archive/refs/tags/v${VERSION_VNC}.tar.gz" -O /tmp/novnc.tar.gz -q --timeout=10 && \
    tar -xf /tmp/novnc.tar.gz -C /tmp/ && \
    cd "/tmp/noVNC-${VERSION_VNC}" && \
    mv app core vendor package.json *.html /usr/share/novnc && \
    unlink /etc/nginx/sites-enabled/default && \
    sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf && \
    echo "$VERSION_ARG" > /run/version && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=qemux/qemu:${VERSION_ARG} /run /run
COPY --from=qemux/qemu:${VERSION_ARG} /var/www /var/www
COPY --from=qemux/qemu:${VERSION_ARG} /usr/share/novnc /usr/share/novnc
COPY --from=qemux/qemu:${VERSION_ARG} /etc/nginx/sites-enabled /etc/nginx/sites-enabled

COPY --chmod=755 ./src /run/

VOLUME /storage
EXPOSE 22 5900 8006

ENV CPU_CORES="2"
ENV RAM_SIZE="2G"
ENV DISK_SIZE="16G"
ENV BOOT="http://example.com/image.iso"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
