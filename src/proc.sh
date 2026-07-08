#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${KVM:="Y"}"
: "${CPU_PIN:=""}"
: "${CPU_FLAGS:=""}"
: "${CPU_MODEL:=""}"

# Sanitize variables
CPU_PIN=$(strip "$CPU_PIN")
CPU_MODEL=$(strip "$CPU_MODEL")
CPU_FLAGS=$(strip "$CPU_FLAGS")

enabled "$DEBUG" && echo "Configuring KVM..."

detectBigLittleCores() {
  local cores same part

  if [[ "${ARCH,,}" != "arm64" ]] || [ -n "$CPU_PIN" ]; then
    return 0
  fi

  # Get a list of the part numbers for the cores
  cores=$(grep '^CPU part\|^processor\|^$' /proc/cpuinfo | tr '\n' '\r' | sed 's/\r\r/\n/g ; s/\r/ /g')

  # Check if all cores have the same part numbers
  same=$(echo "$cores" | awk '{print $7}' | awk '{if (!seen[$0]++){print $0}}' | wc -l | xargs)

  if [[ "$same" != "1" ]]; then

    # Get the part number of the big cores
    part=$(echo "$cores" | awk '{print $7}' | tail -n1)

    # Select only the cores with this part number
    CPU_PIN=$(echo "$cores" | grep -w "$part" | awk '{print $3}' | tr '\n' ',' | sed 's/.$//')

    info "Your CPU has a big.LITTLE architecture, will use only cores ${CPU_PIN}."

  fi

  return 0
}

limitCpuCoresToPinnedCores() {
  local cores

  if [[ "${ARCH,,}" != "arm64" ]] || [ -z "$CPU_PIN" ]; then
    return 0
  fi

  cores=$(echo "$CPU_PIN" | grep -o "," | wc -l)
  cores=$((cores + 1))

  if [ "$CPU_CORES" -gt "$cores" ]; then
    info "The amount for CPU_CORES (${CPU_CORES}) exceeds the amount of pinned cores, so will be limited to ${cores}."
    CPU_CORES="$cores"
  fi

  return 0
}

trimSpaces() {

  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  echo "$value"
  return 0
}

removeCpuArgument() {

  local args=" ${ARGUMENTS:-} "

  while [[ "$args" =~ [[:space:]]-cpu([[:space:]][^[:space:]]+|=[^[:space:]]+)? ]]; do
    local cpu="${BASH_REMATCH[0]}"
    args="${args/$cpu/ }"
    warn "Ignoring '${cpu#" "}' from ARGUMENTS, use CPU_MODEL and CPU_FLAGS instead."
  done

  ARGUMENTS=$(trimSpaces "$args")

  return 0
}

configureKvm() {

  CPU_FEATURES=""
  KVM_OPTS=",accel=kvm -enable-kvm"

  if [ -z "$CPU_MODEL" ]; then
    CPU_MODEL="host"
  fi

  return 0
}

configureTcg() {

  CPU_FEATURES=""
  KVM_OPTS=" -accel tcg,thread=multi"

  if [ -z "$CPU_MODEL" ]; then
    if [[ "${ARCH,,}" == "arm64" ]]; then
      CPU_MODEL="max,pauth-impdef=on"
    else
      CPU_MODEL="cortex-a76"
    fi
  fi

  return 0
}

composeCpuFlags() {

  CPU_FLAGS="${CPU_MODEL}${CPU_FEATURES:+,$CPU_FEATURES}${CPU_FLAGS:+,$CPU_FLAGS}"

  return 0
}

detectBigLittleCores
limitCpuCoresToPinnedCores
removeCpuArgument

if ! disabled "$KVM"; then
  configureKvm
else
  configureTcg
fi

composeCpuFlags

return 0
