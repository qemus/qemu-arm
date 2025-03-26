#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${BIOS:=""}"         # BIOS file
: "${SECURE:="off"}"    # Secure boot

BOOT_DESC=""
BOOT_OPTS=""
[ -n "$BIOS" ] && BOOT_MODE="custom"

case "${BOOT_MODE,,}" in
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
  "legacy" )
    BOOT_DESC=" with SeaBIOS"
    ;;
  "custom" )
    BOOT_OPTS="-bios $BIOS"
    BOOT_DESC=" with custom BIOS file"
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

MSRS="/sys/module/kvm/parameters/ignore_msrs"
if [ -e "$MSRS" ]; then
  result=$(<"$MSRS")
  result="${result//[![:print:]]/}"
  if [[ "$result" == "0" ]] || [[ "${result^^}" == "N" ]]; then
    echo 1 | tee "$MSRS" > /dev/null 2>&1 || true
  fi
fi

CLOCKSOURCE="tsc"
[[ "${ARCH,,}" == "arm64" ]] && CLOCKSOURCE="arch_sys_counter"
CLOCK="/sys/devices/system/clocksource/clocksource0/current_clocksource"

if [ ! -f "$CLOCK" ]; then
  warn "file \"$CLOCK\" cannot not found?"
else
  result=$(<"$CLOCK")
  result="${result//[![:print:]]/}"
  case "${result,,}" in
    "${CLOCKSOURCE,,}" ) ;;
    "kvm-clock" ) info "Nested KVM virtualization detected.." ;;
    "hyperv_clocksource_tsc_page" ) info "Nested Hyper-V virtualization detected.." ;;
    "hpet" ) warn "unsupported clock source ﻿detected﻿: '$result'. Please﻿ ﻿set host clock source to '$CLOCKSOURCE'." ;;
    *) warn "unexpected clock source ﻿detected﻿: '$result'. Please﻿ ﻿set host clock source to '$CLOCKSOURCE'." ;;
  esac
fi

SM_BIOS=""
BIOS_SERIAL=$(</sys/class/dmi/id/product_serial)
BIOS_SERIAL="${BIOS_SERIAL//[![:alnum:]]/}"

if [ -n "$BIOS_SERIAL" ]; then
  SM_BIOS="-smbios type=1,serial=$BIOS_SERIAL"
fi

return 0
