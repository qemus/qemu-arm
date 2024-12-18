#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${VGA:="ramfb"}"         # VGA adaptor
: "${DISPLAY:="web"}"       # Display type

case "${DISPLAY,,}" in
  "vnc" )
    DISPLAY_OPTS="-display vnc=:0 -device $VGA"
    ;;
  "web" | ":0" )
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device $VGA"
    ;;
  "ramfb" )
    DISPLAY_OPTS="-display vnc=:0,websocket=5700 -device ramfb"
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
