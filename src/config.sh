#!/usr/bin/env bash
set -Eeuo pipefail

: "${UUID:=""}"
: "${SERIAL:="mon:stdio"}"
: "${USB:="qemu-xhci,id=xhci"}"
: "${MONITOR:="telnet:localhost:7100,server,nowait,nodelay"}"
: "${SMP:="$CPU_CORES,sockets=1,dies=1,cores=$CPU_CORES,threads=1"}"

DEF_OPTS="-nodefaults"
SERIAL_OPTS="-serial $SERIAL"
CPU_OPTS="-cpu $CPU_FLAGS -smp $SMP"
RAM_OPTS=$(echo "-m ${RAM_SIZE^^}" | sed 's/MB/M/g;s/GB/G/g;s/TB/T/g')
MON_OPTS="-monitor $MONITOR -name $PROCESS,process=$PROCESS,debug-threads=on"
[ -n "$USB" ] && [[ "${USB,,}" != "no"* ]] && USB_OPTS="-device $USB -device usb-kbd -device usb-tablet"
MAC_OPTS="-machine type=${MACHINE},secure=${SECURE},dump-guest-core=off${KVM_OPTS}"
[ -n "$UUID" ] && MAC_OPTS="$MAC_OPTS -uuid $UUID"
DEV_OPTS="-object rng-random,id=objrng0,filename=/dev/urandom"
DEV_OPTS+=" -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pcie.0"
[[ "${BOOT_MODE,,}" != "windows"* ]] && DEV_OPTS+=" -device virtio-balloon-pci,id=balloon0,bus=pcie.0"

ARGS="$DEF_OPTS $CPU_OPTS $RAM_OPTS $MAC_OPTS $DISPLAY_OPTS $MON_OPTS $SERIAL_OPTS ${USB_OPTS:-} $NET_OPTS $DISK_OPTS $BOOT_OPTS $DEV_OPTS $ARGUMENTS"
ARGS=$(echo "$ARGS" | sed 's/\t/ /g' | tr -s ' ')

if [[ "${DISPLAY,,}" == "web" ]]; then
  [ ! -f "$INFO" ] && error "File $INFO not found?!"
  rm -f "$INFO"
  [ ! -f "$PAGE" ] && error "File $PAGE not found?!"
  rm -f "$PAGE"
else
  if [[ "${DISPLAY,,}" == "vnc" ]]; then
    html "You can now connect to VNC on port 5900." "0"
  else
    html "The virtual machine was booted successfully." "0"
  fi
fi

# Check available memory as the very last step

if [[ "$RAM_CHECK" != [Nn]* ]]; then

  RAM_AVAIL=$(free -b | grep -m 1 Mem: | awk '{print $7}')
  AVAIL_GB=$(( RAM_AVAIL/1073741824 ))

  if (( (RAM_WANTED + RAM_SPARE) > RAM_AVAIL )); then
    error "Your configured RAM_SIZE of $WANTED_GB GB is too high for the $AVAIL_GB GB of memory available, please set a lower value."
    exit 17
  fi

  if (( (RAM_WANTED + (RAM_SPARE * 3)) > RAM_AVAIL )); then
    warn "your configured RAM_SIZE of $WANTED_GB GB is very close to the $AVAIL_GB GB of memory available, please consider a lower value."
  fi

fi

if [[ "$DEBUG" == [Yy1]* ]]; then
  printf "Arguments:\n\n%s" "${ARGS// -/$'\n-'}" && echo
fi

return 0
