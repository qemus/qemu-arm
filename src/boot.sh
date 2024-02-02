#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${BIOS:=""}"                 # Bios file

BOOT_OPTS=""
DIR="/usr/share/qemu"

case "${BOOT_MODE,,}" in
  uefi)
    ROM="AAVMF_CODE.fd"
    VARS="AAVMF_VARS.fd"
    ;;
  secure)
    ROM="AAVMF_CODE.fd"
    VARS="AAVMF_VARS.fd"
    ;;
  windows)
    ROM="AAVMF_CODE.ms.fd"
    VARS="AAVMF_VARS.ms.fd"
    ;;
  *)
    info "Unknown boot mode '${BOOT_MODE}', defaulting to 'uefi'"
    BOOT_MODE="uefi"
    ROM="AAVMF_CODE.fd"
    VARS="AAVMF_VARS.fd"
    ;;
esac

if [ -n "$BIOS" ]; then

  BOOT_OPTS="$BOOT_OPTS -bios $DIR/$BIOS"
  return 0

fi

AAVMF="/usr/share/AAVMF/"
DEST="$STORAGE/${BOOT_MODE,,}"

if [ ! -f "$DEST.rom" ]; then
  [ ! -f "$AAVMF/$ROM" ] && error "UEFI boot file ($AAVMF/$ROM) not found!" && exit 44
  cp "$AAVMF/$ROM" "$DEST.rom"
fi

if [ ! -f "$DEST.vars" ]; then
  [ ! -f "$AAVMF/$VARS" ] && error "UEFI vars file ($AAVMF/$VARS) not found!" && exit 45
  cp "$AAVMF/$VARS" "$DEST.vars"
fi

BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

return 0
