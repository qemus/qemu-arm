#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${BIOS:=""}"             # BIOS file

SECURE="off"
BOOT_OPTS=""
BOOT_DESC=""

if [ -n "$BIOS" ]; then
  BOOT_MODE="custom"
  BOOT_OPTS="-bios $BIOS"
  BOOT_DESC=" with custom BIOS file"
  return 0
fi

case "${BOOT_MODE,,}" in
  "legacy" )
    BOOT_DESC=" with SeaBIOS"
    ;;
  "uefi" | "" )
    BOOT_MODE="uefi"
    ROM="AAVMF_CODE.no-secboot.fd"
    VARS="AAVMF_VARS.fd"
    ;;
  "secure" )
    SECURE="on"
    BOOT_DESC=" securely"
    ROM="AAVMF_CODE.secboot.fd"
    VARS="AAVMF_VARS.fd"
    ;;
  "windows" )
    ROM="AAVMF_CODE.no-secboot.fd"
    VARS="AAVMF_VARS.fd"
    BOOT_OPTS="-rtc base=localtime"
    ;;
  "windows_secure" )
    SECURE="on"
    BOOT_DESC=" securely"
    ROM="AAVMF_CODE.ms.fd"
    VARS="AAVMF_VARS.ms.fd"
    BOOT_OPTS="-rtc base=localtime"
    ;;
  *)
    error "Unknown BOOT_MODE, value \"${BOOT_MODE}\" is not recognized!"
    exit 33
    ;;
esac

case "${BOOT_MODE,,}" in
  "uefi" | "secure" | "windows" | "windows_secure" )

    AAVMF="/usr/share/AAVMF/"
    DEST="$STORAGE/${BOOT_MODE,,}"

    if [ ! -s "$DEST.rom" ] || [ ! -f "$DEST.rom" ]; then
      [ ! -s "$AAVMF/$ROM" ] || [ ! -f "$AAVMF/$ROM" ] && error "UEFI boot file ($AAVMF/$ROM) not found!" && exit 44
      rm -f "$DEST.rom"
      dd if=/dev/zero "of=$DEST.rom" bs=1M count=64 status=none
      dd "if=$AAVMF/$ROM" "of=$DEST.rom" conv=notrunc status=none
    fi

    if [ ! -s "$DEST.vars" ] || [ ! -f "$DEST.vars" ]; then
      [ ! -s "$AAVMF/$VARS" ] || [ ! -f "$AAVMF/$VARS" ] && error "UEFI vars file ($AAVMF/$VARS) not found!" && exit 45
      rm -f "$DEST.vars"
      dd if=/dev/zero "of=$DEST.vars" bs=1M count=64 status=none
      dd "if=$AAVMF/$VARS" "of=$DEST.vars" conv=notrunc status=none
    fi

    BOOT_OPTS+=" -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
    BOOT_OPTS+=" -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

    ;;
esac

return 0
