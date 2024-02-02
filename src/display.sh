#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${GPU:="N"}"         # GPU passthrough
: "${VGA:="virtio-vga"}"    # VGA adaptor
: "${DISPLAY:="web"}"   # Display type

case "${DISPLAY,,}" in
  vnc)
    DISPLAY_OPTS="-display vnc=:0 -device $VGA"
    ;;
  web)
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device $VGA"
    ;;
  none)
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display $DISPLAY -device $VGA"
    ;;
esac

return 0
