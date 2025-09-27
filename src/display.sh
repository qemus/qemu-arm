#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:="ramfb"}"         # VGA adaptor
: "${DISPLAY:="web"}"       # Display type

[[ "$DISPLAY" == ":0" ]] && DISPLAY="web"

case "${DISPLAY,,}" in
  "vnc" )
    DISPLAY_OPTS="-display vnc=:0 -device $VGA"
    ;;
  "web" )
    DISPLAY_OPTS="-display vnc=:0,websocket=$WSS_PORT -device $VGA"
    ;;
  "ramfb" )
    DISPLAY_OPTS="-display vnc=:0,websocket=$WSS_PORT -device ramfb"
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
