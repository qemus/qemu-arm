#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${KVM:="Y"}"
: "${CPU_FLAGS:=""}"
: "${DEF_MODEL:="cortex-a53"}"
: "${CPU_MODEL:="$DEF_MODEL"}"

[[ "$ARCH" != "arm"* ]] && KVM="N"

if [[ "$KVM" != [Nn]* ]]; then

  KVM_ERR=""

  if [ ! -e /dev/kvm ]; then
    KVM_ERR="(device file missing)"
  else
    if ! sh -c 'echo -n > /dev/kvm' &> /dev/null; then
      KVM_ERR="(no write access)"
    fi
  fi

  if [ -n "$KVM_ERR" ]; then
    KVM="N"
    error "KVM acceleration not detected $KVM_ERR, this will cause a major loss of performance."
    error "See the FAQ on how to enable it, or continue without KVM by setting KVM=N (not recommended)."
    [[ "$DEBUG" != [Yy1]* ]] && exit 88
  fi

fi

if [[ "$KVM" != [Nn]* ]]; then

  if [[ "$CPU_MODEL" == "$DEF_MODEL" ]]; then
    CPU_MODEL="host"
  fi

  KVM_OPTS=",accel=kvm -enable-kvm"
  CPU_FEATURES="kvm=on,migratable=no"
  WIN_FEATURES=""
  #CPU_FEATURES="kvm=on,l3-cache=on,migratable=no"
  #WIN_FEATURES="+hypervisor,+invtsc,hv_passthrough"

else

  CPU_FEATURES=""
  WIN_FEATURES=""
  KVM_OPTS=" -accel tcg,thread=multi"

  if [[ "$ARCH" == "arm"* ]]; then
    if [[ "$CPU_MODEL" == "$DEF_MODEL" ]]; then
      CPU_MODEL="max"
    fi
  fi

  if [[ "${BOOT_MODE,,}" == "windows" ]]; then
    MACHINE="$MACHINE,virtualization=on"
  fi

fi

if [[ "${BOOT_MODE,,}" == "windows" ]]; then

  [ -n "$CPU_FEATURES" ] && CPU_FEATURES="$CPU_FEATURES,"
  CPU_FEATURES="$CPU_FEATURES${WIN_FEATURES}"

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
