#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:=""}"              # VGA adaptor
: "${DISPLAY:="web"}"       # Display type

if [[ "${BOOT_MODE,,}" != "windows" ]]; then
  [ -z "$VGA" ] && VGA="virtio-gpu"
else
  [ -z "$VGA" ] && VGA="ramfb"
fi

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
  disabled)
    DISPLAY_OPTS="-display none -device $VGA"
    ;;
  none)
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display $DISPLAY -device $VGA"
    ;;
esac

return 0
