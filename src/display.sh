#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${DISPLAY:="web"}"       # Display type
: "${VGA:="virtio-gpu"}"    # VGA adaptor

case "${DISPLAY,,}" in
  vnc)
    DISPLAY_OPTS="-display vnc=:0 -device $VGA"
    ;;
  web)
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device $VGA"
    ;;
  ramfb)
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device ramfb"
    ;;
  none)
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display $DISPLAY -device $VGA"
    ;;
esac

return 0
