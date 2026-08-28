#!/usr/bin/env bash
set -Eeuo pipefail

: "${USB:=""}"
: "${RNG:=""}"
: "${QMP:=""}"
: "${QGA:=""}"
: "${UUID:=""}"
: "${MONITOR:=""}"
: "${RAM_BACKEND:=""}"
: "${KBD:="usb-kbd"}"
: "${SOUND:="usb-audio"}"
: "${MOUSE:="usb-tablet"}"
: "${SERIAL:="mon:stdio"}"
: "${SMP:="$CPU_CORES,sockets=1,dies=1,cores=$CPU_CORES,threads=1"}"

msg="Configuring QEMU..."
enabled "$DEBUG" && echo "$msg"

# Sanitize variables
SMP=$(strip "$SMP")
USB=$(strip "$USB")
QMP=$(strip "$QMP")
QGA=$(strip "$QGA")
KBD=$(strip "$KBD")
UUID=$(strip "$UUID")
SOUND=$(strip "$SOUND")
MOUSE=$(strip "$MOUSE")
SERIAL=$(strip "$SERIAL")
MONITOR=$(strip "$MONITOR")
RAM_BACKEND=$(strip "$RAM_BACKEND")

configureProcessor() {

  CPU_OPTS="-cpu $CPU_FLAGS -smp $SMP"

  return 0
}

configureMemory() {

  local ram
  ram=$(echo "${RAM_SIZE^^}" | sed 's/MB/M/g;s/GB/G/g;s/TB/T/g')

  RAM_OPTS="-m $ram"
  MEM_OPTS=""
  RAM_MACHINE_OPTS=""

  case "${RAM_BACKEND,,}" in
    "" ) ;;
    "memfd" )
      MEM_OPTS="-object memory-backend-memfd,id=ram,size=$ram,share=on"
      RAM_MACHINE_OPTS=",memory-backend=ram" ;;
    * )
      error "Invalid RAM_BACKEND value '$RAM_BACKEND', supported value is 'memfd'."
      exit 78 ;;
  esac

  return 0
}

normalizeSocket() {

  local value="$1"
  local backend="${value%%,*}"

  if [[ "$backend" == *.sock && "$backend" != *:* ]]; then
    value="unix:$value"
    [[ ",$value," == *,server=* ]] || value+=",server=on"
    if [[ ",$value," != *,wait=* ]] && [[ ",$value," != *,server=off,* ]]; then
      value+=",wait=off"
    fi
  fi

  echo "$value"
}

normalizePort() {

  local value="$1"
  local protocol="$2"

  if [[ "$value" =~ ^[0-9]+$ ]]; then
    value="$protocol:0.0.0.0:$value,server=on,wait=off"
  fi

  echo "$value"
}

configureSerial() {

  SERIAL=$(normalizePort "$SERIAL" "telnet")
  SERIAL=$(normalizeSocket "$SERIAL")

  # The interactive console owns stdio, so use the socket relay
  # and keep any non-stdio SERIAL as an additional serial port.
  if enabled "${SHUTDOWN:-}" && interactive; then

    SERIAL_OPTS=""

    if [[ "${SERIAL,,}" != "stdio" && "${SERIAL,,}" != "mon:stdio" ]]; then
      SERIAL_OPTS="-serial $SERIAL"
    fi

    SERIAL_OPTS+="${SERIAL_OPTS:+ }-chardev socket,id=console0,path=$CONSOLE_SOCKET,reconnect-ms=1000"
    SERIAL_OPTS+=" -serial chardev:console0"

  else
    SERIAL_OPTS="-serial $SERIAL"
  fi

  return 0
}

configureMonitor() {

  MON_OPTS=""

  # Keep the user monitor and the automation monitor separate; power
  # and boot-key helpers need a private socket they can control safely.
  if [ -n "${ACPI_SOCKET:-}" ]; then
    MON_OPTS+=" -monitor unix:$ACPI_SOCKET,server=on,wait=off,nodelay=on"
  fi

  if [ -n "$MONITOR" ]; then
    MONITOR=$(normalizePort "$MONITOR" "telnet")
    MONITOR=$(normalizeSocket "$MONITOR")
    MON_OPTS+=" -monitor $MONITOR"
  fi

  if [ -n "$QMP" ]; then
    QMP=$(normalizePort "$QMP" "tcp")
    QMP=$(normalizeSocket "$QMP")
    MON_OPTS+=" -qmp $QMP"
  fi

  ID_OPTS="-name ${APP// /-},process=$PROCESS"
  PID_OPTS="-pidfile $QEMU_PID"

  MON_OPTS="${MON_OPTS# }"
  return 0
}

configureGuestAgent() {

  QGA_OPTS=""

  [ -n "$QGA" ] || return 0

  local qga="$QGA"

  if [[ "$qga" =~ ^[0-9]+$ ]]; then

    qga="host=0.0.0.0,port=$qga,server=on,wait=off"

  else

    local backend="${qga%%,*}"

    if [[ "$backend" == *.sock && "$backend" != *:* ]]; then
      qga=$(normalizeSocket "$qga")
    elif [[ "$backend" != unix:*.sock ]]; then
      error "Invalid QGA value '$QGA', expected a Unix socket path ending in '.sock' or a TCP port."
      exit 78
    fi

    qga="path=${qga#unix:}"

  fi

  QGA_OPTS="-chardev socket,$qga,id=qga0"
  QGA_OPTS+=" -device virtio-serial"
  QGA_OPTS+=" -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"

  return 0
}

configureMachine() {

  local secure="off"
  enabled "$SECURE" && secure="on"

  local usb=""
  disabled "$USB" && usb=",usb=off"

  # Let QEMU select the newest available GIC while exposing the GICv2m MSI
  # frame required by guests that cannot use ITS-based interrupts.
  MAC_OPTS="-machine type=${MACHINE},secure=${secure},gic-version=max,msi=gicv2m"
  MAC_OPTS+="${usb}$RAM_MACHINE_OPTS,dump-guest-core=off${KVM_OPTS}"

  [ -n "$UUID" ] && ID_OPTS+=" -uuid $UUID"
  [ -n "$SM_BIOS" ] && ID_OPTS+=" $SM_BIOS"

  return 0
}

configureDevices() {

  local bus
  bus=$(getPciBus)

  DEV_OPTS=""

  if [ -n "$MOUSE" ] && [[ "${MOUSE,,}" != "usb"* ]]; then
    DEV_OPTS+=" -device $MOUSE"
  fi

  # Windows installation media may not contain the VirtIO RNG driver, so
  # omit the device there instead of risking an unknown-device dependency.
  if ! disabled "$RNG" && [[ "${BOOT_MODE,,}" != "windows"* ]]; then
    DEV_OPTS+=" -object rng-random,id=objrng0,filename=/dev/urandom"
    DEV_OPTS+=" -device virtio-rng-pci,rng=objrng0,id=rng0,bus=$bus"
  fi

  # Non-Windows guests receive a basic balloon by default. Explicit
  # BALLOONING enables QMP statistics and free-page reporting on all guests.
  if [[ "${BOOT_MODE,,}" != "windows"* ]] || enabled "${BALLOONING:-}"; then
    if ! enabled "${BALLOONING:-}"; then
      DEV_OPTS+=" -device virtio-balloon-pci,id=balloon0,bus=$bus"
    else
      MON_OPTS+=" -qmp unix:${BALLOONING_SOCKET},server=on,wait=off"
      DEV_OPTS+=" -device virtio-balloon-pci,free-page-reporting=on,guest-stats-polling-interval=1,id=balloon0,bus=$bus"
    fi
  fi

  DEV_OPTS="${DEV_OPTS# }"

  return 0
}

configureSharedFolder() {

  # Unix-like guests use 9p for the shared folder; Windows guests access
  # the same host content through Samba instead.
  if [ -d "/shared" ] && [[ "${BOOT_MODE,,}" != "windows"* ]]; then
    DEV_OPTS+=" -fsdev local,id=fsdev0,path=/shared,security_model=none"
    DEV_OPTS+=" -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=shared"
  fi

  DEV_OPTS="${DEV_OPTS# }"

  return 0
}

configureUsb() {

  USB_OPTS=""

  if enabled "$USB" || [ -z "$USB" ]; then
    USB="qemu-xhci,id=xhci,p2=7,p3=7"
  fi

  if ! disabled "$USB"; then
    USB_OPTS="-device $USB"
    if [[ "${KBD,,}" == "usb"* ]]; then
      USB_OPTS+=" -device $KBD"
    fi
    if [[ "${MOUSE,,}" == "usb"* ]]; then
      USB_OPTS+=" -device $MOUSE"
    fi
  fi

  return 0
}

configureAudio() {

  AUDIO_OPTS=""

  disabled "${WEB:-}" && return 0
  enabled "${AUDIO:-N}" || return 0

  if [ -z "${AUDIO_FIFO:-}" ] || [ ! -p "$AUDIO_FIFO" ]; then

    disableAudio

    warn "Audio support failed to initialize, ignoring AUDIO=Y."
    return 0
  fi

  local sound="$SOUND"
  local model="${sound%%,*}"

  AUDIO_OPTS+=" -audiodev wav,id=snd,path=$AUDIO_FIFO,out.frequency=48000,out.channels=2,out.format=s16"

  if [[ "$model" == usb-* ]]; then

    if disabled "$USB"; then

      AUDIO_OPTS=""
      disableAudio

      warn "Cannot initialize audio device $model as USB is disabled, ignoring AUDIO=Y."
      return 0
    fi

  fi

  case "$model" in
    intel-hda|ich9-intel-hda)

      AUDIO_OPTS+=" -device $sound"
      AUDIO_OPTS+=" -device hda-output,audiodev=snd" ;;

    *)

      [[ ",$sound," == *,audiodev=* ]] || sound+=",audiodev=snd"
      AUDIO_OPTS+=" -device $sound" ;;

  esac

  return 0
}

configureCompatibility() {

  CMP_OPTS=""

  case "${BOOT_MODE,,}" in
    "legacy" | "windows_legacy" | "custom" )
      return 0 ;;
  esac

  # Disable EDK2's memory-attribute protocol for modern managed firmware;
  # some ARM guests otherwise reject or mishandle its memory protections.
  CMP_OPTS="-fw_cfg name=opt/org.tianocore/UninstallMemAttrProtocol,string=y"

  return 0
}

buildArguments() {

  ARGS="-nodefaults $MEM_OPTS $MAC_OPTS $CPU_OPTS $RAM_OPTS $ID_OPTS $PID_OPTS $DISPLAY_OPTS $MON_OPTS $SERIAL_OPTS $QGA_OPTS $USB_OPTS $NET_OPTS $DISK_OPTS $BOOT_OPTS $DEV_OPTS $AUDIO_OPTS $CMP_OPTS $ARGUMENTS"

  # Collapse whitespace after optional argument groups are assembled so
  # empty features do not leave malformed spacing in the final command.
  ARGS=$(echo "$ARGS" | sed 's/\t/ /g' | tr -s ' ')

  return 0
}

finalizeMemory

configureMemory
configureSerial
configureMonitor
configureGuestAgent
configureMachine
configureProcessor

configureDevices
configureSharedFolder
configureUsb
configureAudio
configureCompatibility

buildArguments

return 0
