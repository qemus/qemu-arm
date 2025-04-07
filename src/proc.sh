#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${KVM:="Y"}"
: "${CPU_PIN:=""}"
: "${CPU_FLAGS:=""}"
: "${CPU_MODEL:=""}"
: "${DEF_MODEL:="neoverse-n1"}"

if [[ "$CPU" == "Cortex A53" ]] && [[ "$CORES" == "6" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 4
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5"
fi

if [[ "$CPU" == "Cortex A55" ]] && [[ "$CORES" == "8" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 5
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5,6,7"
fi

if [[ "$CPU" == "Rockchip RK3588"* ]] && [[ "$CORES" == "8" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 5 Plus
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5,6,7"
fi

if [[ "${ARCH,,}" != "arm64" ]]; then
  KVM="N"
  warn "your CPU architecture is ${ARCH^^} and cannot provide KVM acceleration for ARM64 instructions, this will cause a major loss of performance."
fi

if [[ "$KVM" != [Nn]* ]]; then

  KVM_ERR=""

  if [ ! -e /dev/kvm ]; then
    KVM_ERR="(/dev/kvm is missing)"
  else
    if ! sh -c 'echo -n > /dev/kvm' &> /dev/null; then
      KVM_ERR="(/dev/kvm is unwriteable)"
    fi
  fi

  if [ -n "$KVM_ERR" ]; then
    KVM="N"
    if [[ "$OSTYPE" =~ ^darwin ]]; then
      warn "you are using macOS which has no KVM support, this will cause a major loss of performance."
    else      
      kernel=$(uname -a)
      case "${kernel,,}" in
        *"microsoft"* )
          error "Please bind '/dev/kvm' as a volume in the optional container settings when using Docker Desktop." ;;
        *"synology"* )
          error "Please make sure that Synology VMM (Virtual Machine Manager) is installed and that '/dev/kvm' is binded to this container." ;;
        *)
          error "KVM acceleration is not available $KVM_ERR, this will cause a major loss of performance."
          error "See the FAQ for possible causes, or continue without it by adding KVM: \"N\" (not recommended)." ;;
      esac
      [[ "$DEBUG" != [Yy1]* ]] && exit 88
    fi
  fi

fi

if [[ "$KVM" != [Nn]* ]]; then

  CPU_FEATURES=""
  KVM_OPTS=",accel=kvm -enable-kvm"

  if [ -z "$CPU_MODEL" ]; then
    CPU_MODEL="host"
  fi

else

  CPU_FEATURES=""
  KVM_OPTS=" -accel tcg,thread=multi"

  if [ -z "$CPU_MODEL" ]; then
    if [[ "${ARCH,,}" == "arm64" ]]; then
      CPU_MODEL="max,pauth-impdef=on"
    else
      CPU_MODEL="$DEF_MODEL"
    fi
  fi

  if [[ "${BOOT_MODE,,}" == "windows" ]]; then
    MACHINE+=",virtualization=on"
  fi

fi

if [ -z "$CPU_FLAGS" ]; then
  if [ -z "$CPU_FEATURES" ]; then
    CPU_FLAGS="$CPU_MODEL"
  else
    CPU_FLAGS="$CPU_MODEL,$CPU_FEATURES"
  fi
else
  if [ -z "$CPU_FEATURES" ]; then
    CPU_FLAGS="$CPU_MODEL,$CPU_FLAGS"
  else
    CPU_FLAGS="$CPU_MODEL,$CPU_FEATURES,$CPU_FLAGS"
  fi
fi

return 0
