#!/usr/bin/env bash
set -Eeuo pipefail

getURL() {
  local id="${1/ /}"
  local ret="$2"
  local url=""
  local name=""

  case "${id,,}" in
    "alma" )
      name="AlmaLinux"
      url="https://repo.almalinux.org/almalinux/9/live/aarch64/AlmaLinux-9.5-aarch64-Live-GNOME.iso" ;;
    "alpine" )
      name="Alpine Linux"
      url="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-virt-3.19.1-aarch64.iso" ;;
    "arch" )
      name="Arch Linux"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "cachy" | "cachyos" )
      name="CachyOS"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "centos" )
      name="CentOS Stream"
      url="https://mirrors.xtom.de/centos-stream/10-stream/BaseOS/aarch64/iso/CentOS-Stream-10-latest-aarch64-dvd1.iso" ;;
    "debian" )
      name="Debian"
      url="https://cdimage.debian.org/debian-cd/current/arm64/iso-dvd/debian-12.9.0-arm64-DVD-1.iso" ;;
    "endeavour" | "endeavouros" )
      name="EndeavourOS"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "fedora" )
      name="Fedora Linux"
      url="https://eu.edge.kernel.org/fedora/releases/41/Workstation/aarch64/images/Fedora-Workstation-41-1.4.aarch64.raw.xz" ;;
    "gentoo" )
      name="Gentoo Linux"
      url="https://distfiles.gentoo.org/releases/arm64/autobuilds/20250309T234826Z/di-arm64-cloudinit-20250309T234826Z.qcow2" ;;
    "kali" )
      name="Kali Linux"
      url="https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-live-arm64.iso" ;;
    "kubuntu" )
      name="Kubuntu"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "macos" | "osx" )
      name="macOS"
      error "To install $name use: https://github.com/dockur/macos" && return 1 ;;
    "mint" | "linuxmint" )
      name="Linux Mint"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "manjaro" )
      name="Manjaro"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "mx" )
      name="MX Linux"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "nixos" )
      name="NixOS"
      url="https://channels.nixos.org/nixos-24.11/latest-nixos-gnome-aarch64-linux.iso" ;;
    "opensuse" | "suse" )
      name="OpenSUSE"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "oracle" )
      name="Oracle Linux"
      url="https://yum.oracle.com/ISOS/OracleLinux/OL9/u5/aarch64/OracleLinux-R9-U5-aarch64-boot-uek.iso" ;;
    "rocky" )
      name="Rocky Linux"
      url="https://dl.rockylinux.org/pub/rocky/9/live/aarch64/Rocky-9-Workstation-aarch64-latest.iso" ;;
    "slack" | "slackware" )
      name="Slackware"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "tails" )
      name="Tails"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
    "ubuntu" )
      name="Ubuntu Desktop"
      url="https://cdimage.ubuntu.com/ubuntu/releases/24.10/release/ubuntu-24.10-desktop-arm64.iso" ;;
    "ubuntus" )
      name="Ubuntu Server"
      url="https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.2-live-server-arm64.iso" ;;
    "windows" )
      name="Windows"
      error "To install $name use: https://github.com/dockur/windows" && return 1 ;;
    "xubuntu" )
      name="Xubuntu"
      error "No image for $name is available for ARM64 yet! " && return 1 ;;
  esac

  case "${ret,,}" in
    "test" ) ;;
    "name" ) echo "$name" ;;
    *) echo "$url";;
  esac

  return 0
}

return 0
