#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${GPU:="N"}"         # GPU passthrough
: "${DISPLAY:="web"}"   # Display type

case "${DISPLAY,,}" in
  vnc)
    DISPLAY_OPTS="-display vnc=:0"
    ;;
  web)
    DISPLAY_OPTS="-display vnc=:0,websocket=5700"
    ;;
  none)
    DISPLAY_OPTS="-display none"
    ;;
  *)
    DISPLAY_OPTS="-display $DISPLAY"
    ;;
esac

return 0
