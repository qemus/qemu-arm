#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${BIOS:=""}"         # BIOS file
: "${SECURE:="off"}"    # Secure boot
: "${LOGO:="Y"}"        # Enable logo
: "${CLEAR:="N"}"       # Persist NVRAM

BOOT_DESC=""
BOOT_OPTS=""

configureBootMode() {

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
      error "BOOT_MODE=legacy is not supported!"
      exit 33
      ;;
    "custom" )
      BIOS=$(strip "$BIOS")
      if [ -z "$BIOS" ]; then
        error "BOOT_MODE is custom but BIOS is empty!"
        exit 33
      fi
      BOOT_OPTS="-bios $BIOS"
      BOOT_DESC=" with custom BIOS file"
      ;;
    *)
      error "Unknown BOOT_MODE, value \"${BOOT_MODE}\" is not recognized!"
      exit 33
      ;;
  esac

  return 0
}

clearNvram() {

  DEST="$STORAGE/${BOOT_MODE,,}"

  if enabled "$CLEAR"; then
    # Clear NVRAM (helps to fix corruptions)
    rm -f "$DEST.rom" "$DEST.vars" "$DEST.tpm"
  fi

  return 0
}

writePflashImage() {

  local source="$1"
  local target="$2"

  rm -f "$target"

  if ! dd if=/dev/zero "of=$target" bs=1M count=64 status=none; then
    rm -f "$target"
    return 1
  fi

  if ! dd "if=$source" "of=$target" conv=notrunc status=none; then
    rm -f "$target"
    return 1
  fi

  return 0
}

prepareUefiRom() {

  local logo

  if [ -e "$DEST.rom" ] && [ ! -f "$DEST.rom" ]; then
    error "UEFI boot path \"$DEST.rom\" is not a regular file!"
    exit 44
  fi

  [ -s "$DEST.rom" ] && return 0

  [ ! -s "$AAVMF/$ROM" ] && error "UEFI boot file ($AAVMF/$ROM) not found!" && exit 44

  rm -f "$DEST.tmp"

  logo="/var/www/img/${PROCESS,,}.ffs"
  [ ! -s "$logo" ] && logo="/var/www/img/qemu.ffs"
  [ ! -s "$logo" ] && LOGO="N"

  if ! dd if=/dev/zero "of=$DEST.tmp" bs=1M count=64 status=none; then
    rm -f "$DEST.tmp"
    error "Failed to create UEFI boot file $DEST.tmp" && exit 44
  fi

  if disabled "$LOGO"; then
    if ! dd "if=$AAVMF/$ROM" "of=$DEST.tmp" conv=notrunc status=none; then
      rm -f "$DEST.tmp"
      error "Failed to copy UEFI boot file to $DEST.tmp" && exit 44
    fi
  else
    if /run/utk.bin "$AAVMF/$ROM" replace_ffs LogoDXE "$logo" save "$DEST.logo"; then
      if ! dd "if=$DEST.logo" "of=$DEST.tmp" conv=notrunc status=none; then
        rm -f "$DEST.tmp" "$DEST.logo"
        error "Failed to copy custom UEFI boot file to $DEST.tmp" && exit 44
      fi
    else
      warn "failed to add custom logo to BIOS!"

      if ! dd "if=$AAVMF/$ROM" "of=$DEST.tmp" conv=notrunc status=none; then
        rm -f "$DEST.tmp" "$DEST.logo"
        error "Failed to copy UEFI boot file to $DEST.tmp" && exit 44
      fi
    fi
    rm -f "$DEST.logo"
  fi

  if ! mv "$DEST.tmp" "$DEST.rom"; then
    rm -f "$DEST.tmp"
    error "Failed to move UEFI boot file to $DEST.rom" && exit 44
  fi

  ! setOwner "$DEST.rom" && warn "failed to set the owner for \"$DEST.rom\" !"

  return 0
}

prepareUefiVars() {

  if [ -e "$DEST.vars" ] && [ ! -f "$DEST.vars" ]; then
    error "UEFI vars path \"$DEST.vars\" is not a regular file!"
    exit 44
  fi

  [ -s "$DEST.vars" ] && return 0

  [ ! -s "$AAVMF/$VARS" ] && error "UEFI vars file ($AAVMF/$VARS) not found!" && exit 45

  rm -f "$DEST.tmp"

  if ! writePflashImage "$AAVMF/$VARS" "$DEST.tmp"; then
    rm -f "$DEST.tmp"
    error "Failed to copy UEFI vars file to $DEST.tmp" && exit 45
  fi

  if ! mv "$DEST.tmp" "$DEST.vars"; then
    rm -f "$DEST.tmp"
    error "Failed to move UEFI vars file to $DEST.vars" && exit 45
  fi

  ! setOwner "$DEST.vars" && warn "failed to set the owner for \"$DEST.vars\" !"

  return 0
}

configureUefi() {

  case "${BOOT_MODE,,}" in
    "uefi" | "secure" | "windows" | "windows_secure" )

      AAVMF="/usr/share/AAVMF"

      prepareUefiRom
      prepareUefiVars

      BOOT_OPTS+=" -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
      BOOT_OPTS+=" -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

      ;;
  esac

  return 0
}

enableIgnoreMsrs() {

  MSRS="/sys/module/kvm/parameters/ignore_msrs"

  if [ -e "$MSRS" ]; then
    result=$(<"$MSRS")
    result="${result//[![:print:]]/}"
    if [[ "$result" == "0" || "${result^^}" == "N" ]]; then
      echo 1 | tee "$MSRS" > /dev/null 2>&1 || true
    fi
  fi

  return 0
}

checkClocksource() {

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

  return 0
}

detectSmbiosSerial() {

  SM_BIOS=""
  PS="/sys/class/dmi/id/product_serial"

  if [ -r "$PS" ]; then

    BIOS_SERIAL=$(<"$PS")
    BIOS_SERIAL="${BIOS_SERIAL//[![:alnum:]]/}"

    if [ -n "$BIOS_SERIAL" ]; then
      SM_BIOS="-smbios type=1,serial=$BIOS_SERIAL"
    fi

  fi

  return 0
}

msg="Configuring boot..."

html "$msg"
enabled "$DEBUG" && echo "$msg"

configureBootMode
clearNvram
configureUefi
enableIgnoreMsrs
checkClocksource
detectSmbiosSerial

return 0
