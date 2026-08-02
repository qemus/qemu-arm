#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${CPU_MODEL:=""}"    # QEMU CPU mode
: "${CPU_FLAGS:=""}"    # Additional QEMU CPU flags
: "${CPU_PIN:=""}"      # Pins QEMU to specific host CPU cores

enabled "$DEBUG" && echo "Configuring KVM..."

# Sanitize variables
CPU_PIN=$(strip "$CPU_PIN")
CPU_MODEL=$(strip "$CPU_MODEL")
CPU_FLAGS=$(strip "$CPU_FLAGS")

CPUINFO_FILE="${CPUINFO_FILE:-/proc/cpuinfo}"
CPU_STATUS_FILE="${CPU_STATUS_FILE:-/proc/self/status}"
CPU_SYSFS_ROOT="${CPU_SYSFS_ROOT:-/sys/devices/system/cpu}"

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

trimSpaces() {

  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  echo "$value"
  return 0
}

expandCpuList() {

  local item start end cpu
  local -a items

  IFS=',' read -r -a items <<< "$1"

  for item in "${items[@]}"; do

    item="${item//[[:space:]]/}"
    [ -n "$item" ] || continue

    if [[ "$item" == *-* ]]; then
      start="${item%%-*}"
      end="${item#*-}"
    else
      start="$item"
      end="$item"
    fi

    [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]] || return 1
    (( end >= start )) || return 1

    for (( cpu=start; cpu<=end; cpu++ )); do
      echo "$cpu"
    done

  done

  return 0
}

getAllowedCpuList() {

  local list=""

  [ -r "$CPU_STATUS_FILE" ] &&
    list=$(awk '$1 == "Cpus_allowed_list:" { print $2; exit }' "$CPU_STATUS_FILE")

  [ -z "$list" ] && [ -r "$CPU_SYSFS_ROOT/online" ] && list=$(<"$CPU_SYSFS_ROOT/online")

  echo "$list"
  return 0
}

getCpuInfoSignature() {

  local cpu="$1"

  [ -r "$CPUINFO_FILE" ] || return 0

  awk -F ':' -v target="$cpu" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function emit() {
      if (!found && current == target && implementer != "" && part != "") {
        print tolower(implementer ":" architecture ":" variant ":" part ":" revision)
        found = 1
      }
    }

    /^[[:space:]]*processor[[:space:]]*:/ {
      emit()
      current = trim($2)
      implementer = architecture = variant = part = revision = ""
      next
    }

    /^[[:space:]]*CPU implementer[[:space:]]*:/ { implementer = trim($2); next }
    /^[[:space:]]*CPU architecture[[:space:]]*:/ { architecture = trim($2); next }
    /^[[:space:]]*CPU variant[[:space:]]*:/ { variant = trim($2); next }
    /^[[:space:]]*CPU part[[:space:]]*:/ { part = trim($2); next }
    /^[[:space:]]*CPU revision[[:space:]]*:/ { revision = trim($2); next }

    END { emit() }
  ' "$CPUINFO_FILE"

  return 0
}

getCpuCacheSignature() {

  local root="$CPU_SYSFS_ROOT/cpu${1}/cache"
  local index field value signature=""

  [ -d "$root" ] || return 0

  while read -r index; do

    [ -d "$index" ] || continue
    signature+=";"

    for field in level type size coherency_line_size number_of_sets ways_of_associativity; do
      value=""
      [ -r "$index/$field" ] && value=$(<"$index/$field")
      value="${value//[[:space:]]/}"
      signature+="${value,,}:"
    done

  done < <(printf '%s\n' "$root"/index* | sort -V)

  echo "$signature"
  return 0
}

getCpuSignature() {

  local cpu="$1"
  local midr=""
  local model=""
  local cache

  if [ -r "$CPU_SYSFS_ROOT/cpu${cpu}/regs/identification/midr_el1" ]; then
    midr=$(<"$CPU_SYSFS_ROOT/cpu${cpu}/regs/identification/midr_el1")
    midr="${midr//[[:space:]]/}"
    [[ "$midr" =~ ^0[xX][0-9a-fA-F]+$ ]] && model="midr:${midr,,}"
  fi

  if [ -z "$model" ]; then
    model=$(getCpuInfoSignature "$cpu")
    [ -n "$model" ] && model="cpuinfo:$model"
  fi

  cache=$(getCpuCacheSignature "$cpu")
  echo "${model:-unknown}|cache:$cache"

  return 0
}

getCpuMetric() {

  local value="0"

  [ -r "$1" ] && value=$(<"$1")
  value="${value//[[:space:]]/}"
  [[ "$value" =~ ^[0-9]+$ ]] || value="0"

  echo "$value"
  return 0
}

getCpuMaxFrequency() {

  local root="$CPU_SYSFS_ROOT/cpu${1}/cpufreq"
  local value

  value=$(getCpuMetric "$root/cpuinfo_max_freq")
  (( value > 0 )) || value=$(getCpuMetric "$root/scaling_max_freq")

  echo "$value"
  return 0
}

detectBigLittleCores() {

  local -a cpus=()
  local allowed cpu online signature capacity frequency key
  local selected="" best_capacity="-1" best_frequency="-1" best_count="-1"
  local -A group_cpus=() group_count=() group_capacity=() group_frequency=()

  if [[ "${ARCH,,}" != "arm64" ]] || [ -n "$CPU_PIN" ] || disabled "${KVM:-}"; then
    return 0
  fi

  allowed=$(getAllowedCpuList)
  [ -n "$allowed" ] || return 0

  while read -r cpu; do

    [ -d "$CPU_SYSFS_ROOT/cpu${cpu}" ] || continue

    online="1"
    [ -r "$CPU_SYSFS_ROOT/cpu${cpu}/online" ] && online=$(<"$CPU_SYSFS_ROOT/cpu${cpu}/online")
    [[ "$online" == "1" ]] && cpus+=("$cpu")

  done < <(expandCpuList "$allowed" 2>/dev/null || :)

  (( ${#cpus[@]} > 1 )) || return 0

  for cpu in "${cpus[@]}"; do

    signature=$(getCpuSignature "$cpu")
    capacity=$(getCpuMetric "$CPU_SYSFS_ROOT/cpu${cpu}/cpu_capacity")
    frequency=$(getCpuMaxFrequency "$cpu")

    group_cpus["$signature"]="${group_cpus[$signature]:+${group_cpus[$signature]},}$cpu"
    group_count["$signature"]=$(( ${group_count[$signature]:-0} + 1 ))

    (( capacity > ${group_capacity[$signature]:-0} )) && group_capacity["$signature"]="$capacity"
    (( frequency > ${group_frequency[$signature]:-0} )) && group_frequency["$signature"]="$frequency"

  done

  (( ${#group_count[@]} > 1 )) || return 0

  for key in "${!group_count[@]}"; do

    capacity="${group_capacity[$key]:-0}"
    frequency="${group_frequency[$key]:-0}"

    if (( capacity > best_capacity )) ||
       (( capacity == best_capacity && frequency > best_frequency )) ||
       (( capacity == best_capacity && frequency == best_frequency && group_count["$key"] > best_count )) ||
       { (( capacity == best_capacity && frequency == best_frequency && group_count["$key"] == best_count )) &&
         [[ -z "$selected" || "${group_cpus[$key]}" < "${group_cpus[$selected]}" ]]; }; then

      selected="$key"
      best_capacity="$capacity"
      best_frequency="$frequency"
      best_count="${group_count[$key]}"

    fi

  done

  [ -n "$selected" ] || return 0
  CPU_PIN="${group_cpus[$selected]}"

  if (( best_capacity > 0 || best_frequency > 0 )); then
    info "Your CPU has a heterogeneous architecture, will use the fastest homogeneous cores ${CPU_PIN}."
  else
    info "Your CPU has a heterogeneous architecture, will use homogeneous cores ${CPU_PIN}."
  fi

  return 0
}

countPinnedCores() {

  local list="${1//[[:space:]]/}"
  local item cpu
  local -a items
  local -A cpus

  IFS=',' read -r -a items <<< "$list"

  for item in "${items[@]}"; do

    [ -n "$item" ] || return 1

    local range="$item"
    local stride="1"

    if [[ "$range" == *:* ]]; then
      stride="${range##*:}"
      range="${range%:*}"
    fi

    if [[ "$range" == *-* ]]; then
      local start="${range%%-*}"
      local end="${range#*-}"
    else
      local start="$range"
      local end="$range"
    fi

    if [[ ! "$start" =~ ^[0-9]+$ ||
          ! "$end" =~ ^[0-9]+$ ||
          ! "$stride" =~ ^[0-9]+$ ]] ||
      (( stride < 1 || end < start )); then
      return 1
    fi

    for (( cpu=start; cpu<=end; cpu+=stride )); do
      cpus["$cpu"]=1
    done

  done

  echo "${#cpus[@]}"
  return 0
}

limitCpuCoresToPinnedCores() {

  local cores

  if [[ "${ARCH,,}" != "arm64" ]] || [ -z "$CPU_PIN" ]; then
    return 0
  fi

  if ! cores=$(countPinnedCores "$CPU_PIN"); then
    warn "Could not determine the number of pinned cores from CPU_PIN='$CPU_PIN'."
    return 0
  fi

  if [ "$CPU_CORES" -gt "$cores" ]; then
    info "The amount for CPU_CORES (${CPU_CORES}) exceeds the amount of pinned cores, so will be limited to ${cores}."
    CPU_CORES="$cores"
  fi

  return 0
}

composeCpuFlags() {

  CPU_FLAGS="${CPU_MODEL}${CPU_FEATURES:+,$CPU_FEATURES}${CPU_FLAGS:+,$CPU_FLAGS}"

  return 0
}

removeCpuArgument
detectBigLittleCores
limitCpuCoresToPinnedCores

if ! disabled "${KVM:-}"; then
  configureKvm
else
  configureTcg
fi

composeCpuFlags

return 0
