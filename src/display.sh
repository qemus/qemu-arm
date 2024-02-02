#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${DISPLAY:="web"}"           # Display
: "${VGA:="virtio-gpu"}"        # GPU model

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
