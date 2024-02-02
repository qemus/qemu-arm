#!/usr/bin/env bash
set -Eeuo pipefail

APP="QEMU"
SUPPORT="https://github.com/qemus/qemu-arm"

cd /run

. reset.sh      # Initialize system
. install.sh    # Get bootdisk
. disk.sh       # Initialize disks
. network.sh    # Initialize network
. boot.sh       # Configure boot
. display.sh    # Initialize graphics
. proc.sh       # Initialize processor
. config.sh     # Configure arguments

trap - ERR

info "Booting image using $VERS..."

[[ "$DEBUG" == [Yy1]* ]] && set -x
exec qemu-system-aarch64 ${ARGS:+ $ARGS}
