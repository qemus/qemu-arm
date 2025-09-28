#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:="ramfb"}"         # VGA adaptor
: "${DISPLAY:="web"}"       # Display type

port=$(( VNC_PORT - 5900 ))
[[ "$DISPLAY" == ":0" ]] && DISPLAY="web"

case "${DISPLAY,,}" in
  "vnc" )
    DISPLAY_OPTS="-display vnc=:$port -device $VGA"
    ;;
  "web" )
    DISPLAY_OPTS="-display vnc=:$port,websocket=$WSS_PORT -device $VGA"
    ;;
  "ramfb" )
    DISPLAY_OPTS="-display vnc=:$port,websocket=$WSS_PORT -device ramfb"
    ;;
  "disabled" )
    DISPLAY_OPTS="-display none -device $VGA"
    ;;
  "none" )
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display $DISPLAY -device $VGA"
    ;;
esac

return 0
