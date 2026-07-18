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

VGA_OPTS=""
[ -n "$VGA" ] && [[ "${VGA,,}" != "none" ]] && VGA_OPTS="-device $VGA"

LOSSY_OPT=""
enabled "${LOSSY}" && LOSSY_OPT=",lossy=on"

port=$(( VNC_PORT - 5900 ))
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
