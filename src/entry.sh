#!/usr/bin/env bash
set -Eeuo pipefail

: "${APP:="QEMU"}"
: "${MACHINE:="virt"}"
: "${PLATFORM:="arm64"}"
: "${SUPPORT:="https://github.com/qemus/qemu-arm"}"

cd /run

. start.sh      # Startup hook
. utils.sh      # Load functions
. reset.sh      # Initialize system
. server.sh     # Start webserver
. define.sh     # Define images
. install.sh    # Download image
. disk.sh       # Initialize disks
. display.sh    # Initialize graphics
. network.sh    # Initialize network
. boot.sh       # Configure boot
. proc.sh       # Initialize processor
. memory.sh     # Check available memory
. config.sh     # Configure arguments
. finish.sh     # Finish initialization

trap - ERR

version=$(qemu-system-aarch64 --version | head -n 1 | cut -d '(' -f 1 | awk '{ print $NF }')
info "Booting image${BOOT_DESC} using QEMU v$version..."

if [ -z "$CPU_PIN" ]; then
  exec qemu-system-aarch64 ${ARGS:+ $ARGS}
else
  exec taskset -c "$CPU_PIN" qemu-system-aarch64 ${ARGS:+ $ARGS}
fi
