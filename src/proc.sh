#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${KVM:="Y"}"
: "${CPU_PIN:=""}"
: "${CPU_FLAGS:=""}"
: "${CPU_MODEL:=""}"
: "${DEF_MODEL:="cortex-a76"}"

if [[ "${ARCH,,}" == "arm64" ]] && [ -z "$CPU_PIN" ]; then

  # Get a list of the part numbers for the cores
  cores=$(cat /proc/cpuinfo | grep '^CPU part\|^processor\|^$' | tr '\n' '\r' | sed 's/\r\r/\n/g ; s/\r/ /g')

  # Check if all cores have the same part numbers
  same=$(echo "$cores" | awk '{print $7}' | awk '{if (!seen[$0]++){print $0}}' | wc -l)

  if [[ "$same" != "1" ]]; then

    # Get the part number of the big cores
    part=$(echo "$cores" | awk '{print $7}' | tail -n1)

    # Select only the cores with this part number
    CPU_PIN=$(echo "$cores" | grep -w "$part" | awk '{print $3}' | tr '\n' ',' | sed 's/.$//')

    info "Your CPU has a big.LITTLE architecture, will use only cores ${CPU_PIN}."

  fi

fi

if [[ "${ARCH,,}" == "arm64" ]] && [ -n "$CPU_PIN" ]; then

  cores=$(echo "$CPU_PIN" | grep -o "," | wc -l);
  cores=$((cores + 1)); 

  if [ "$CPU_CORES" -gt "$cores" ]; then
    info "The amount for CPU_CORES (${CPU_CORES}) exceeds the amount of pinned cores, so will be limited to ${cores}."
    CPU_CORES="$cores"
  fi

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

fi

if [[ "$ARGUMENTS" == *"-cpu host,"* ]]; then

  args="${ARGUMENTS} "
  prefix="${args/-cpu host,*/}"
  suffix="${args/*-cpu host,/}"
  param="${suffix%% *}"
  suffix="${suffix#* }"
  args="${prefix}${suffix}"
  ARGUMENTS="${args::-1}"

  if [ -z "$CPU_FLAGS" ]; then
    CPU_FLAGS="$param"
  else
    CPU_FLAGS+=",$param"
  fi

else

  if [[ "$ARGUMENTS" == *"-cpu host"* ]]; then
    ARGUMENTS="${ARGUMENTS//-cpu host/}"
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
