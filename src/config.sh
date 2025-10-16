#!/usr/bin/env bash
set -Eeuo pipefail

: "${UUID:=""}"
: "${SERIAL:="mon:stdio"}"
: "${USB:="qemu-xhci,id=xhci,p2=7,p3=7"}"
: "${MONITOR:="telnet:localhost:7100,server,nowait,nodelay"}"
: "${SMP:="$CPU_CORES,sockets=1,dies=1,cores=$CPU_CORES,threads=1"}"

msg="Configuring QEMU..."
html "$msg"
[[ "$DEBUG" == [Yy1]* ]] && echo "$msg"

DEF_OPTS="-nodefaults"
SERIAL_OPTS="-serial $SERIAL"
CPU_OPTS="-cpu $CPU_FLAGS -smp $SMP"
RAM_OPTS=$(echo "-m ${RAM_SIZE^^}" | sed 's/MB/M/g;s/GB/G/g;s/TB/T/g')
MON_OPTS="-monitor $MONITOR -name $PROCESS,process=$PROCESS,debug-threads=on"
MAC_OPTS="-machine type=${MACHINE},secure=${SECURE},gic-version=max,dump-guest-core=off${KVM_OPTS}"

[ -n "$UUID" ] && MAC_OPTS+=" -uuid $UUID"
[ -n "$SM_BIOS" ] && MAC_OPTS+=" $SM_BIOS"

DEV_OPTS="-object rng-random,id=objrng0,filename=/dev/urandom"
DEV_OPTS+=" -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pcie.0"

if [[ "${BOOT_MODE,,}" != "windows"* ]]; then
  DEV_OPTS+=" -device virtio-balloon-pci,id=balloon0,bus=pcie.0"
fi

if [ -d "/shared" ] && [[ "${BOOT_MODE,,}" != "windows"* ]]; then
  DEV_OPTS+=" -fsdev local,id=fsdev0,path=/shared,security_model=none"
  DEV_OPTS+=" -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=shared"
fi

[ -n "$USB" ] && [[ "${USB,,}" != "no"* ]] && USB_OPTS="-device $USB -device usb-kbd -device usb-tablet"

ARGS="$DEF_OPTS $CPU_OPTS $RAM_OPTS $MAC_OPTS $DISPLAY_OPTS $MON_OPTS $SERIAL_OPTS ${USB_OPTS:-} $NET_OPTS $DISK_OPTS $BOOT_OPTS $DEV_OPTS $ARGUMENTS"
ARGS=$(echo "$ARGS" | sed 's/\t/ /g' | tr -s ' ')

return 0
