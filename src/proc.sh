#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${KVM:="Y"}"
: "${CPU_FLAGS:=""}"
: "${CPU_MODEL:=""}"
: "${DEF_MODEL:="neoverse-n1"}"

[[ "${ARCH,,}" != "arm"* ]] && KVM="N"

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
    if [[ "$OSTYPE" =~ ^darwin ]]; then
      warn "you are using MacOS which has no KVM support, this will cause a major loss of performance."
    else
      error "KVM acceleration not available $KVM_ERR, this will cause a major loss of performance."
      error "See the FAQ on how to enable it, or continue without KVM by setting KVM=N (not recommended)."
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
    if [[ "$ARCH" == "arm"* ]]; then
      CPU_MODEL="max,pauth-impdef=on"
    else
      CPU_MODEL="$DEF_MODEL"
    fi
  fi

  if [[ "${BOOT_MODE,,}" == "windows" ]]; then
    MACHINE="$MACHINE,virtualization=on"
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
