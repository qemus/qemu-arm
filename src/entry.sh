#!/usr/bin/env bash
set -Eeuo pipefail

PLATFORM="arm64"

: "${APP:="QEMU"}"
: "${MACHINE:="virt"}"
: "${SUPPORT:="https://github.com/qemus/qemu-arm"}"

cd /run

. utils.sh      # Load functions
. reset.sh      # Initialize system
. define.sh     # Define images
. install.sh    # Download image
. disk.sh       # Initialize disks
. display.sh    # Initialize graphics
. network.sh    # Initialize network
. boot.sh       # Configure boot
. proc.sh       # Initialize processor
. config.sh     # Configure arguments

trap - ERR

version=$(qemu-system-aarch64 --version | head -n 1 | cut -d '(' -f 1 | awk '{ print $NF }')
info "Booting image${BOOT_DESC} using QEMU v$version..."

if [ -z "$CPU_PIN" ]; then
  exec qemu-system-aarch64 ${ARGS:+ $ARGS}
else
  exec taskset -c "$CPU_PIN" qemu-system-aarch64 ${ARGS:+ $ARGS}
fi
