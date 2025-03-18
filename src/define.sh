#!/usr/bin/env bash
set -Eeuo pipefail

pipe() {
  local code="99"
  msg="Failed to connect to $1, reason:"

  curl --disable --silent --max-time 10 --fail --location "${1}" || {
    code="$?"
  }

  case "${code,,}" in
    "6" ) error "$msg could not resolve host!" ;;
    "7" ) error "$msg no internet connection available!" ;;
    "28" ) error "$msg connection timed out!" ;;
    "99" ) return 0 ;;
    *) error "$msg $code" ;;
  esac

  return 1
}

getURL() {
  local id="${1/ /}"
  local ret="$2"
  local url=""
  local arm=""
  local name=""
  local body=""
  local version=""

  case "${id,,}" in
    "alma" | "almalinux" | "alma-linux" )
      name="AlmaLinux"
      if [[ "$ret" == "url" ]]; then
        url="https://repo.almalinux.org/almalinux/9/live/x86_64/AlmaLinux-9-latest-x86_64-Live-GNOME.iso"
        arm="https://repo.almalinux.org/almalinux/9/live/aarch64/AlmaLinux-9-latest-aarch64-Live-GNOME.iso"
      fi ;;
    "alpine" | "alpinelinux" | "alpine-linux" )
      name="Alpine Linux"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml") || exit 65
        version=$(echo "$body" | awk '/"Xen"/{found=0} {if(found) print} /"Virtual"/{found=1}' | grep 'version:' | awk '{print $2}')
        url="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-virt-$version-x86_64.iso"
        arm="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/alpine-virt-$version-aarch64.iso"
      fi ;;
    "arch" | "archlinux" | "arch-linux" )
      name="Arch Linux"
      if [[ "$ret" == "url" ]]; then
        url="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
      fi ;;
    "cachy" | "cachyos" )
      name="CachyOS"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://cachyos.org/download/") || exit 65
        url=$(echo "$body" | tr '&' '\n' | grep "ISO/desktop" | grep -v 'iso.sha' | grep -v 'iso.sig' | cut -d';' -f2)
        arm=$(echo "$body" | tr '&' '\n' | grep "ISO/handheld" | grep -v 'iso.sha' | grep -v 'iso.sig' | cut -d';' -f2)
      fi ;;
    "centos" | "centosstream" | "centos-stream" )
      name="CentOS Stream"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://linuxsoft.cern.ch/centos-stream/") || exit 65
        version=$(echo "$body" | grep "\-stream" | cut -d'"' -f 6 | cut -d'-' -f 1 | head -n 1)
        url="https://mirrors.xtom.de/centos-stream/$version-stream/BaseOS/x86_64/iso/CentOS-Stream-$version-latest-x86_64-dvd1.iso"
        arm="https://mirrors.xtom.de/centos-stream/$version-stream/BaseOS/aarch64/iso/CentOS-Stream-$version-latest-aarch64-dvd1.iso"
      fi ;;
    "debian" )
      name="Debian"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://cdimage.debian.org/debian-cd/") || exit 65
        version=$(echo "$body" | grep '\.[0-9]/' | cut -d'>' -f 9 | cut -d'/' -f 1)
        url="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-$version-amd64-standard.iso"
        arm="https://cdimage.debian.org/debian-cd/current/arm64/iso-dvd/debian-$version-arm64-DVD-1.iso"
      fi ;;
    "fedora" | "fedoralinux" | "fedora-linux" )
      name="Fedora Linux"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://getfedora.org/releases.json") || exit 65
        version=$(echo "$body" | jq -r 'map(.version) | unique | .[]' | sed 's/ /_/g' | sort -r | head -n 1)
        url=$(echo "$body" | jq -r "map(select(.arch==\"x86_64\" and .version==\"${version}\" and .variant==\"Workstation\" and .subvariant==\"Workstation\" )) | .[].link")
        arm=$(echo "$body" | jq -r "map(select(.arch==\"aarch64\" and .version==\"${version}\" and .variant==\"Workstation\" and .subvariant==\"Workstation\" )) | .[].link")
      fi ;;
    "gentoo" | "gentoolinux" | "gentoo-linux" )
      name="Gentoo Linux"
      if [[ "$ret" == "url" ]]; then
        if [[ "${ARCH,,}" != "arm64" ]]; then
          body=$(pipe "https://mirror.bytemark.co.uk/gentoo/releases/amd64/autobuilds/latest-iso.txt") || exit 65
          version=$(echo "$body" | grep livegui | cut -d' ' -f1)
          url="https://distfiles.gentoo.org/releases/amd64/autobuilds/$version"
        else
          body=$(pipe "https://mirror.bytemark.co.uk/gentoo/releases/arm64/autobuilds/latest-qcow2.txt")  || exit 65
          version=$(echo "$body" | grep cloudinit | cut -d' ' -f1)
          arm="https://distfiles.gentoo.org/releases/arm64/autobuilds/$version"
        fi
      fi ;;
    "kali" | "kalilinux" | "kali-linux" )
      name="Kali Linux"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://cdimage.kali.org/current/?C=M;O=D") || exit 65
        version=$(echo "$body" | grep -o ">kali-linux-.*-live-amd64.iso" | head -n 1 | cut -c 2-)
        url="https://cdimage.kali.org/current/$version"
        version=$(echo "$body" | grep -o ">kali-linux-.*-live-arm64.iso" | head -n 1 | cut -c 2-)
        arm="https://cdimage.kali.org/current/$version"
      fi ;;
    "kubuntu" )
      name="Kubuntu"
      if [[ "$ret" == "url" ]]; then
        url="https://cdimage.ubuntu.com/kubuntu/releases/24.10/release/kubuntu-24.10-desktop-amd64.iso"
      fi ;;
    "lmde" )
      name="Linux Mint Debian Edition"
      if [[ "$ret" == "url" ]]; then
        url="https://mirror.rackspace.com/linuxmint/iso/debian/lmde-6-cinnamon-64bit.iso"
      fi ;;
    "macos" | "osx" )
      name="macOS"
      error "To install $name use: https://github.com/dockur/macos" && return 1 ;;
    "mint" | "linuxmint" | "linux-mint" )
      name="Linux Mint"
      if [[ "$ret" == "url" ]]; then
        url="https://mirrors.layeronline.com/linuxmint/stable/22.1/linuxmint-22.1-cinnamon-64bit.iso"
      fi ;;
    "manjaro" )
      name="Manjaro"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://gitlab.manjaro.org/web/iso-info/-/raw/master/file-info.json") || exit 65
        url=$(echo "$body" | jq -r .official.plasma.image)
      fi ;;
    "mx" | "mxlinux" | "mx-linux" )
      name="MX Linux"
      if [[ "$ret" == "url" ]]; then
        version=$(curl --disable -Ils "https://sourceforge.net/projects/mx-linux/files/latest/download" | grep -i 'location:' | cut -d? -f1 | cut -d_ -f1 | cut -d- -f3) || exit 65
        url="https://mirror.umd.edu/mxlinux-iso/MX/Final/Xfce/MX-${version}_x64.iso"
      fi ;;
    "nixos" )
      name="NixOS"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://nix-channels.s3.amazonaws.com/?delimiter=/") || exit 65
        version=$(echo "$body" | grep -o -E 'nixos-[[:digit:]]+\.[[:digit:]]+' | cut -d- -f2 | sort -nru | head -n 1)
        url="https://channels.nixos.org/nixos-$version/latest-nixos-gnome-x86_64-linux.iso"
        arm="https://channels.nixos.org/nixos-$version/latest-nixos-gnome-aarch64-linux.iso"
      fi ;;
    "opensuse" | "open-suse" | "suse" )
      name="OpenSUSE"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://download.opensuse.org/distribution/leap/") || exit 65
        version=$(echo "$body" | grep 'class="name"' | cut -d '/' -f2 | grep -v 42 | sort -r | head -n 1) 
        url="https://download.opensuse.org/distribution/leap/$version/installer/iso/agama-installer-Leap.x86_64-Leap.iso"
        arm="https://download.opensuse.org/distribution/leap/$version/installer/iso/agama-installer-Leap.aarch64-Leap.iso"
      fi ;;
    "oracle" | "oraclelinux" | "oracle-linux" )
      name="Oracle Linux"
      if [[ "$ret" == "url" ]]; then
        url="https://yum.oracle.com/ISOS/OracleLinux/OL9/u5/x86_64/OracleLinux-R9-U5-x86_64-boot.iso"
        arm="https://yum.oracle.com/ISOS/OracleLinux/OL9/u5/aarch64/OracleLinux-R9-U5-aarch64-boot-uek.iso"
      fi ;;
    "rocky" | "rockylinux" | "rocky-linux" )
      name="Rocky Linux"
      if [[ "$ret" == "url" ]]; then
        url="https://dl.rockylinux.org/pub/rocky/9/live/x86_64/Rocky-9-Workstation-x86_64-latest.iso"
        arm="https://dl.rockylinux.org/pub/rocky/9/live/aarch64/Rocky-9-Workstation-aarch64-latest.iso"
      fi ;;
    "slack" | "slackware" )
      name="Slackware"
      if [[ "$ret" == "url" ]]; then
        url="https://slackware.nl/slackware-live/slackware64-current-live/slackware64-live-current.iso"
      fi ;;
    "tails" )
      name="Tails"
      if [[ "$ret" == "url" ]]; then
        body=$(pipe "https://tails.net/install/v2/Tails/amd64/stable/latest.json") || exit 65
        url=$(echo "$body" | jq -r '.installations[0]."installation-paths"[]|select(.type=="iso")|."target-files"[0].url')
      fi ;;
    "ubuntu" | "ubuntu-desktop" )
      name="Ubuntu Desktop"
      if [[ "$ret" == "url" ]]; then
        url="https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-desktop-amd64.iso"
        arm="https://cdimage.ubuntu.com/ubuntu/releases/24.10/release/ubuntu-24.10-desktop-arm64.iso"
      fi ;;
    "ubuntus" | "ubuntu-server")
      name="Ubuntu Server"
      if [[ "$ret" == "url" ]]; then
        url="https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
        arm="https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.2-live-server-arm64.iso"
      fi ;;
    "windows" )
      name="Windows"
      error "To install $name use: https://github.com/dockur/windows" && return 1 ;;
    "xubuntu" )
      name="Xubuntu"
      if [[ "$ret" == "url" ]]; then
        url="https://mirror.us.leaseweb.net/ubuntu-cdimage/xubuntu/releases/24.04/release/xubuntu-24.04.2-desktop-amd64.iso"
      fi ;;
  esac

  case "${ret,,}" in
    "name" )
      echo "$name"
      ;;
    "url" )

      if [[ "${ARCH,,}" != "arm64" ]]; then
        if [ -n "$name" ] && [ -z "$url" ]; then
          error "No image for $name available!"
          return 1
        fi
      else
        if [ -n "$name" ] && [ -z "$arm" ]; then
          error "No image for $name is available for ARM64 yet! "
          return 1
        fi
      fi

      if [[ "${ARCH,,}" != "arm64" ]]; then
        echo "$url"
      else
        echo "$arm"
      fi ;;
  esac

  return 0
}

return 0
