#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:="VGA"}"               # Adaptor
: "${DISPLAY:="web"}"           # Display

case "${DISPLAY,,}" in
  vnc)
    DISPLAY_OPTS="-display vnc=:0 -device virto-gpu"
    ;;
  web)
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device virto-gpu"
    ;;
  boot)
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
