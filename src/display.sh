#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:="ramfb"}"         # VGA adaptor
: "${DISPLAY:="web"}"       # Display type
: "${LOSSY:="N"}"           # Lossy VNC compression

# Sanitize variables
VGA=$(strip "$VGA")
LOSSY=$(strip "$LOSSY")
DISPLAY=$(strip "$DISPLAY")

# Resolve friendly VirtIO aliases to the PCI device and place it on the
# machine-specific bus selected by the shared QEMU helpers.
case "${VGA,,}" in
  "virtio" | "virtio-gpu" | "viogpu" )
    VGA="virtio-gpu-pci,bus=$(getPciBus)"
    ;;
esac

VGA_OPTS=""
[ -n "$VGA" ] && [[ "${VGA,,}" != "none" ]] && VGA_OPTS="-device $VGA"

LOSSY_OPT=""
enabled "${LOSSY}" && LOSSY_OPT=",lossy=on"

# QEMU accepts a VNC display number rather than a TCP port, so translate
# the configured port back to its :N display index.
port=$(( VNC_PORT - 5900 ))
# Preserve the historic :0 setting as an alias for the managed web display.
[[ "$DISPLAY" == ":0" ]] && DISPLAY="web"

case "${DISPLAY,,}" in
  "vnc" )
    DISPLAY_OPTS="-display vnc=:${port}${LOSSY_OPT} ${VGA_OPTS}"
    ;;
  "web" )
    DISPLAY_OPTS="-display vnc=:${port},websocket=${WSS_PORT}${LOSSY_OPT} ${VGA_OPTS}"
    ;;
  "ramfb" )
    DISPLAY_OPTS="-display vnc=:${port},websocket=${WSS_PORT}${LOSSY_OPT} -device ramfb"
    ;;
  # disabled keeps the configured display device available to the guest
  # without a frontend; none removes both the frontend and VGA device.
  "disabled" )
    DISPLAY_OPTS="-display none ${VGA_OPTS}"
    ;;
  "none" )
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display ${DISPLAY} ${VGA_OPTS}"
    ;;
esac

return 0
