#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${TPM:="Y"}"         # Enable TPM
: "${BIOS:=""}"        # Bios file
: "${BOOT_MODE:="uefi"}"  # Boot mode

SECURE=""
DIR="/usr/share/qemu"
BOOT_OPTS="-device ramfb"

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

if [ -n "$BIOS"]; then

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

if [[ "${BOOT_MODE,,}" != "uefi" ]]; then
  SECURE=",smm=on"
  BOOT_OPTS="$BOOT_OPTS -global driver=cfi.pflash01,property=secure,value=on"
fi

BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.rom,if=pflash,unit=0,format=raw,readonly=on"
BOOT_OPTS="$BOOT_OPTS -drive file=$DEST.vars,if=pflash,unit=1,format=raw"

if [[ "${BOOT_MODE,,}" == "windows" ]]; then

  BOOT_OPTS="$BOOT_OPTS -global kvm-pit.lost_tick_policy=discard -global ICH9-LPC.disable_s3=1"

  if [[ "$TPM" == [Yy1]* ]]; then

    rm -rf /run/shm/tpm
    rm -f /var/run/tpm.pid
    mkdir -p /run/shm/tpm
    chmod 755 /run/shm/tpm

    if ! swtpm socket -t -d --tpmstate dir=/run/shm/tpm --ctrl type=unixio,path=/run/swtpm-sock --pid file=/var/run/tpm.pid --tpm2; then
      error "Failed to start TPM emulator, reason: $?" && exit 19
    fi

    for (( i = 1; i < 20; i++ )); do

      [ -S "/run/swtpm-sock" ] && break

      if (( i % 10 == 0 )); then
        echo "Waiting for TPM socket to become available..."
      fi

      sleep 0.1

    done

    if [ ! -S "/run/swtpm-sock" ]; then
      TPM="N"
      error "TPM socket not found? Disabling TPM support..."
    else
      BOOT_OPTS="$BOOT_OPTS -chardev socket,id=chrtpm,path=/run/swtpm-sock"
      BOOT_OPTS="$BOOT_OPTS -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0"
    fi

  fi
fi

return 0
