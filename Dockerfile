# syntax=docker/dockerfile:1

ARG VERSION_ARG="latest"

FROM qemux/qemu:${VERSION_ARG} AS src
FROM debian:trixie-slim

ARG TARGETARCH
ARG VERSION_ARG="0.0"
ARG VERSION_QMP="0.0.6"
ARG VERSION_WSD="0.4.2"
ARG VERSION_UTK="1.3.0"
ARG VERSION_EFI="2026.05-2"
ARG VERSION_PASST="2026_07_28"
ARG VERSION_SEABIOS="1.17.0-1"
ARG VERSION_QEMU="1:11.1.0+ds-2"
ARG DEBIAN_SNAPSHOT="20260819T142328Z"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN <<EOF
  set -eu

  echo "deb https://deb.debian.org/debian trixie non-free" > /etc/apt/sources.list.d/non-free.list

  apt-get update
  apt-get --no-install-recommends -y install \
    bc \
    jq \
    xxd \
    tini \
    wget \
    7zip \
    7zip-rar \
    curl \
    aria2 \
    fdisk \
    nginx \
    unzip \
    procps \
    ipcalc \
    ethtool \
    python3 \
    python3-pip \
    iptables \
    iproute2 \
    dnsmasq \
    xorriso \
    pciutils \
    xz-utils \
    apt-utils \
    net-tools \
    e2fsprogs \
    diffutils \
    util-linux \
    iputils-ping \
    genisoimage \
    inotify-tools \
    netcat-openbsd \
    ca-certificates

  # Install QEMU 11 and AArch64 UEFI firmware from Debian Sid
  echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}/ sid main" \
    > /etc/apt/sources.list.d/qemu-snapshot.list

  apt-get update
  apt-get --no-install-recommends -y -t sid install \
    "seabios=${VERSION_SEABIOS}" \
    "qemu-utils=${VERSION_QEMU}" \
    "qemu-efi-aarch64=${VERSION_EFI}" \
    "qemu-system-arm=${VERSION_QEMU}"

  # Install QMP
  pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore "qemu.qmp==${VERSION_QMP}"

  # Install Passt package
  wget "https://github.com/qemus/passt/releases/download/v${VERSION_PASST}/passt_${VERSION_PASST}_${TARGETARCH}.deb" -O /tmp/passt.deb -q --timeout=10
  dpkg -i /tmp/passt.deb

  # Install Websocketd package
  wget "https://github.com/qemus/websocketd/releases/download/v${VERSION_WSD}/websocketd-${VERSION_WSD}_${TARGETARCH}.deb" -O /tmp/wsd.deb -q --timeout=10
  dpkg -i /tmp/wsd.deb

  rm -f /etc/apt/sources.list.d/qemu-snapshot.list
  apt-get clean

  # Set version file
  echo "$VERSION_ARG" > /etc/version

  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

COPY --from=src /run/*.sh /run/
COPY --from=src /run/*.py /run/
COPY --from=src /var/www /var/www
COPY --from=src /usr/share/novnc /usr/share/novnc
COPY --from=src /etc/nginx/default.conf /etc/nginx/default.conf

COPY --chmod=755 ./src /run/
COPY --chmod=755 ./web /var/www/

ADD --chmod=755 "https://github.com/qemus/boot-logo/releases/download/v${VERSION_UTK}/boot-logo_${TARGETARCH}.bin" /run/boot-logo

VOLUME /storage
EXPOSE 22 5900 8006

ENV BOOT="alpine"
ENV CPU_CORES="2"
ENV RAM_SIZE="2G"
ENV DISK_SIZE="64G"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
