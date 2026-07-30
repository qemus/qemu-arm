# syntax=docker/dockerfile:1

ARG VERSION_ARG="latest"

FROM qemux/qemu:${VERSION_ARG} AS src
FROM debian:trixie-slim

ARG TARGETARCH
ARG VERSION_ARG="0.0"
ARG VERSION_QMP="0.0.6"
ARG VERSION_UTK="1.2.0"
ARG VERSION_PASST="2026_07_28"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN <<EOF
  set -eu

  apt-get update
  apt-get --no-install-recommends -y install \
    bc \
    jq \
    xxd \
    tini \
    wget \
    7zip \
    curl \
    aria2 \
    fdisk \
    nginx \
    procps \
    ipcalc \
    ethtool \
    seabios \
    iptables \
    iproute2 \
    dnsmasq \
    xorriso \
    xz-utils \
    apt-utils \
    net-tools \
    e2fsprogs \
    diffutils \
    qemu-utils \
    util-linux \
    websocketd \
    iputils-ping \
    genisoimage \
    inotify-tools \
    netcat-openbsd \
    ca-certificates \
    qemu-system-arm \
    qemu-efi-aarch64 \
    python3 \
    python3-pip

  # Install QMP
  pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore "qemu.qmp==${VERSION_QMP}"

  # Install Passt package
  wget "https://github.com/qemus/passt/releases/download/v${VERSION_PASST}/passt_${VERSION_PASST}_${TARGETARCH}.deb" -O /tmp/passt.deb -q --timeout=10
  dpkg -i /tmp/passt.deb

  apt-get clean

  # Disable the default nginx site
  unlink /etc/nginx/sites-enabled/default

  # Set version file
  echo "$VERSION_ARG" > /etc/version

  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

COPY --from=src /run/*.sh /run/
COPY --from=src /run/*.py /run/
COPY --from=src /var/www /var/www
COPY --from=src /usr/share/novnc /usr/share/novnc

COPY --from=src /etc/qemu/bridge.conf /etc/qemu/bridge.conf
COPY --from=src /etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=src /etc/nginx/default.conf /etc/nginx/default.conf

COPY --chmod=755 ./src /run/
COPY --chmod=755 ./web /var/www/

ADD --chmod=755 "https://github.com/qemus/fiano/releases/download/v${VERSION_UTK}/utk_${VERSION_UTK}_${TARGETARCH}.bin" /run/utk.bin

VOLUME /storage
EXPOSE 22 5900 8006

ENV BOOT="alpine"
ENV CPU_CORES="2"
ENV RAM_SIZE="2G"
ENV DISK_SIZE="64G"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
