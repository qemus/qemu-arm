#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${BIOS:=""}"         # BIOS file
: "${SECURE:="off"}"    # Secure boot
: "${LOGO:="Y"}"        # Enable logo
: "${CLEAR:="N"}"       # Persist NVRAM

BOOT_DESC=""
BOOT_OPTS=""
[ -n "$BIOS" ] && BOOT_MODE="custom"

msg="Configuring boot..."
html "$msg"
enabled "$DEBUG" && echo "$msg"

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

DEST="$STORAGE/${BOOT_MODE,,}"

if enabled "$CLEAR"; then
  # Clear NVRAM (helps to fix corruptions)
  rm -f "$DEST.rom" "$DEST.vars" "$DEST.tpm"
fi

case "${BOOT_MODE,,}" in
  "uefi" | "secure" | "windows" | "windows_secure" )

    AAVMF="/usr/share/AAVMF"

    if [ ! -s "$DEST.rom" ]; then
      [ ! -s "$AAVMF/$ROM" ] && error "UEFI boot file ($AAVMF/$ROM) not found!" && exit 44
      rm -f "$DEST.tmp"
      
      logo="/var/www/img/${PROCESS,,}.ffs"
      [ ! -s "$logo" ] && logo="/var/www/img/qemu.ffs"
      [ ! -s "$logo" ] && LOGO="N"
    
      dd if=/dev/zero "of=$DEST.tmp" bs=1M count=64 status=none
      if disabled "$LOGO"; then
        dd "if=$AAVMF/$ROM" "of=$DEST.tmp" conv=notrunc status=none
      else
        if /run/utk.bin "$AAVMF/$ROM" replace_ffs LogoDXE "$logo" save "$DEST.logo"; then
          dd "if=$DEST.logo" "of=$DEST.tmp" conv=notrunc status=none
        else
          warn "failed to add custom logo to BIOS!"
          dd "if=$AAVMF/$ROM" "of=$DEST.tmp" conv=notrunc status=none
        fi
        rm -f "$DEST.logo"
      fi
      mv "$DEST.tmp" "$DEST.rom"
      ! setOwner "$DEST.rom" && error "Failed to set the owner for \"$DEST.rom\" !"
    fi

    if [ ! -s "$DEST.vars" ]; then
      [ ! -s "$AAVMF/$VARS" ] && error "UEFI vars file ($AAVMF/$VARS) not found!" && exit 45
      rm -f "$DEST.tmp"
      dd if=/dev/zero "of=$DEST.tmp" bs=1M count=64 status=none
      dd "if=$AAVMF/$VARS" "of=$DEST.tmp" conv=notrunc status=none
      mv "$DEST.tmp" "$DEST.vars"
      ! setOwner "$DEST.vars" && error "Failed to set the owner for \"$DEST.vars\" !"
    fi

    BOOT_OPTS+=" -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
    BOOT_OPTS+=" -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

    ;;
esac

MSRS="/sys/module/kvm/parameters/ignore_msrs"
if [ -e "$MSRS" ]; then
  result=$(<"$MSRS")
  result="${result//[![:print:]]/}"
  if [[ "$result" == "0" || "${result^^}" == "N" ]]; then
    echo 1 | tee "$MSRS" > /dev/null 2>&1 || true
  fi
fi

CLOCKSOURCE="tsc"
[[ "${ARCH,,}" == "arm64" ]] && CLOCKSOURCE="arch_sys_counter"
CLOCK="/sys/devices/system/clocksource/clocksource0/current_clocksource"

if [ ! -f "$CLOCK" ]; then
  warn "file \"$CLOCK\" cannot be found?"
else
  result=$(<"$CLOCK")
  result="${result//[![:print:]]/}"
  case "${result,,}" in
    "${CLOCKSOURCE,,}" ) ;;
    "kvm-clock" ) info "Nested KVM virtualization detected.." ;;
    "hyperv_clocksource_tsc_page" ) info "Nested Hyper-V virtualization detected.." ;;
    "hpet" ) warn "unsupported clock source detected: '$result'. Please set host clock source to '$CLOCKSOURCE'." ;;
    *) warn "unexpected clock source detected: '$result'. Please set host clock source to '$CLOCKSOURCE'." ;;
  esac
fi

SM_BIOS=""
PS="/sys/class/dmi/id/product_serial"

if [ -s "$PS" ] && [ -r "$PS" ]; then

  BIOS_SERIAL=$(<"$PS")
  BIOS_SERIAL="${BIOS_SERIAL//[![:alnum:]]/}"

  if [ -n "$BIOS_SERIAL" ]; then
    SM_BIOS="-smbios type=1,serial=$BIOS_SERIAL"
  fi

fi

return 0
