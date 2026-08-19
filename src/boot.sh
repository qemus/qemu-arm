#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${LOGO:=""}"         # Enable logo
: "${CLEAR:=""}"        # Clear NVRAM
: "${SECURE:=""}"       # Secure Boot

BOOT_DESC=""
BOOT_OPTS=""

configureBootMode() {

  case "${BOOT_MODE,,}" in

    "uefi" | "" )

      BOOT_MODE="uefi"

      VARS="AAVMF_VARS.fd"
      ROM="AAVMF_CODE.no-secboot.fd" ;;

    "secure" )

      BOOT_DESC=" securely"

      [ -z "$SECURE" ] && SECURE="Y"

      VARS="AAVMF_VARS.fd"
      ROM="AAVMF_CODE.secboot.fd" ;;

    "windows" )

      VARS="AAVMF_VARS.fd"
      ROM="AAVMF_CODE.no-secboot.fd"

      # Windows expects the emulated RTC to contain local time rather than
      # UTC, unlike the default convention used by most Unix guests.
      BOOT_OPTS="-rtc base=localtime" ;;

    "windows_secure" )

      BOOT_DESC=" securely"

      [ -z "$SECURE" ] && SECURE="Y"

      ROM="AAVMF_CODE.ms.fd"
      VARS="AAVMF_VARS.ms.fd"

      BOOT_OPTS="-rtc base=localtime" ;;

    *)
      error "Unknown BOOT_MODE, value \"${BOOT_MODE}\" is not recognized!"
      exit 33 ;;

  esac

  return 0
}

clearNvram() {

  DEST="$STORAGE/${BOOT_MODE,,}"

  enabled "$CLEAR" || return 0

  # Clear NVRAM (helps to fix corruptions)
  rm -f "$DEST.rom" "$DEST.vars" "$DEST.tpm"

  return 0
}

writePflashImage() {

  local source="$1"
  local target="$2"

  rm -f "$target"

  # AAVMF pflash devices are exposed as fixed 64 MiB images, so pad the
  # firmware payload before copying it without truncating the container.
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

  if [ -e "$DEST.rom" ] && [ ! -f "$DEST.rom" ]; then
    error "UEFI boot path \"$DEST.rom\" is not a regular file!"
    exit 44
  fi

  # Keep the prepared firmware persistent across restarts. CLEAR must be
  # used when a changed firmware or boot logo should be regenerated.
  [ -s "$DEST.rom" ] && return 0

  local rom="$AAVMF/$ROM"
  [ ! -s "$rom" ] && error "UEFI boot file ($rom) not found!" && exit 44

  local logo="/var/www/img/${PROCESS,,}.bmp"
  [ ! -s "$logo" ] && logo="/var/www/img/qemu.bmp"

  if ! disabled "$LOGO" && [ ! -s "$logo" ]; then
    LOGO="N"
    warn "boot logo file ($logo) not found!"
  fi

  # Build the ROM through a temporary file so an interrupted logo patch or
  # copy cannot replace the last usable firmware image.
  rm -f "$DEST.tmp" "$DEST.logo"

  if ! dd if=/dev/zero "of=$DEST.tmp" bs=1M count=64 status=none; then
    rm -f "$DEST.tmp"
    error "Failed to create UEFI boot file $DEST.tmp" && exit 44
  fi

  if ! disabled "$LOGO"; then
    if /run/boot-logo "$logo" "$rom" --output "$DEST.logo" -q; then
      rom="$DEST.logo"
    else
      warn "failed to add custom logo ($logo) to UEFI firmware!"
    fi
  fi

  if ! dd "if=$rom" "of=$DEST.tmp" conv=notrunc status=none; then
    rm -f "$DEST.tmp" "$DEST.logo"
    error "Failed to copy UEFI boot file to $DEST.tmp" && exit 44
  fi

  rm -f "$DEST.logo"

  if ! mv "$DEST.tmp" "$DEST.rom"; then
    rm -f "$DEST.tmp"
    error "Failed to move UEFI boot file to $DEST.rom" && exit 44
  fi

  setOwner "$DEST.rom" || warn "failed to set the owner for \"$DEST.rom\" !"

  return 0
}

prepareUefiVars() {

  if [ -e "$DEST.vars" ] && [ ! -f "$DEST.vars" ]; then
    error "UEFI vars path \"$DEST.vars\" is not a regular file!"
    exit 44
  fi

  # NVRAM variables are guest-writable and therefore persist separately
  # from the read-only firmware code image.
  [ -s "$DEST.vars" ] && return 0

  local vars="$AAVMF/$VARS"
  [ ! -s "$vars" ] && error "UEFI vars file ($vars) not found!" && exit 45

  rm -f "$DEST.tmp"

  if ! writePflashImage "$vars" "$DEST.tmp"; then
    rm -f "$DEST.tmp"
    error "Failed to copy UEFI vars file to $DEST.tmp" && exit 45
  fi

  if ! mv "$DEST.tmp" "$DEST.vars"; then
    rm -f "$DEST.tmp"
    error "Failed to move UEFI vars file to $DEST.vars" && exit 45
  fi

  setOwner "$DEST.vars" || warn "failed to set the owner for \"$DEST.vars\" !"

  return 0
}

configureUefi() {

  case "${BOOT_MODE,,}" in

    "uefi" | "secure" | "windows" | "windows_secure" )

      AAVMF="/usr/share/AAVMF"

      prepareUefiRom
      prepareUefiVars

      # Unit 0 is immutable firmware code; unit 1 is the writable variable
      # store that carries boot entries and Secure Boot state.
      BOOT_OPTS+=" -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
      BOOT_OPTS+=" -drive file=$DEST.vars,if=pflash,unit=1,format=raw" ;;

  esac

  return 0
}

enableIgnoreMsrs() {

  MSRS="/sys/module/kvm/parameters/ignore_msrs"

  [ -e "$MSRS" ] || return 0

  # Unsupported guest MSR accesses should not terminate KVM. This is
  # best-effort because containers may not be allowed to change the module.
  result=$(<"$MSRS")
  result="${result//[![:print:]]/}"

  if [[ "$result" == "0" || "${result^^}" == "N" ]]; then
    echo 1 | tee "$MSRS" > /dev/null 2>&1 || true
  fi

  return 0
}

checkClocksource() {

  CLOCKSOURCE="tsc"
  [[ "${ARCH,,}" == "arm64" ]] && CLOCKSOURCE="arch_sys_counter"
  CLOCK="/sys/devices/system/clocksource/clocksource0/current_clocksource"

  if [ ! -f "$CLOCK" ]; then
    warn "file \"$CLOCK\" cannot be found?"
    return 0
  fi

  result=$(<"$CLOCK")
  result="${result//[![:print:]]/}"

  # Native ARM and x86 hosts have different preferred clocksources;
  # paravirtual clocks identify expected nested-virtualization setups.
  case "${result,,}" in
    "${CLOCKSOURCE,,}" ) ;;
    "kvm-clock" ) info "Nested KVM virtualization detected.." ;;
    "hyperv_clocksource_tsc_page" ) info "Nested Hyper-V virtualization detected.." ;;
    "hpet" ) warn "unsupported clock source detected: '$result'. Please set host clock source to '$CLOCKSOURCE'." ;;
    *) warn "unexpected clock source detected: '$result'. Please set host clock source to '$CLOCKSOURCE'." ;;
  esac

  return 0
}

detectSmbiosSerial() {

  SM_BIOS=""
  PS="/sys/class/dmi/id/product_serial"

  [ -r "$PS" ] || return 0

  BIOS_SERIAL=$(<"$PS")
  BIOS_SERIAL="${BIOS_SERIAL//[![:alnum:]]/}"

  if [ -n "$BIOS_SERIAL" ]; then
    # Reuse a sanitized host product serial to provide a stable guest
    # machine identity without passing punctuation into QEMU's option list.
    SM_BIOS="-smbios type=1,serial=$BIOS_SERIAL"
  fi

  return 0
}

msg="Configuring boot..."

html "$msg"
enabled "$DEBUG" && echo "$msg"

configureBootMode

[ -z "$SECURE" ] && SECURE="N"

clearNvram
configureUefi
enableIgnoreMsrs
checkClocksource
detectSmbiosSerial

return 0
