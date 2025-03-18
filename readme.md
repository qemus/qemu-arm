<h1 align="center">QEMU ARM64<br />
<div align="center">
<a href="https://github.com/qemus/qemu-arm"><img src="https://github.com/qemus/qemu-arm/raw/master/.github/logo.png" title="Logo" style="max-width:100%;" width="128" /></a>
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Package]][pkg_url]
[![Pulls]][hub_url]

</div></h1>

Docker container for running ARM-based virtual machines using QEMU, for devices like the Raspberry Pi 5 and many others.

## Features ✨

  - Web-based viewer to control the machine directly from your browser

  - Supports `.iso`, `.img`, `.qcow2`, `.vhd`, `.vhdx`, `.vdi`, `.vmdk` and `.raw` disk formats

  - High-performance options (like KVM acceleration, kernel-mode networking, IO threading, etc.) to achieve near-native speed

## Usage  🐳

Via Docker Compose:

```yaml
services:
  qemu:
    container_name: qemu
    image: qemux/qemu-arm
    environment:
      BOOT: "alpine"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:80
    volumes:
      - ./qemu:/storage
    restart: always
    stop_grace_period: 2m
```

Via Docker CLI:

```bash
docker run -it --rm --name qemu -e "BOOT=alpine" -p 8006:80 --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -v ${PWD:-.}/qemu:/storage --stop-timeout 120 qemux/qemu-arm
```

Via Kubernetes:

```shell
kubectl apply -f https://raw.githubusercontent.com/qemus/qemu-arm/refs/heads/master/kubernetes.yml
```

## Compatibility ⚙️

| **Product**  | **Platform**   | |
|---|---|---|
| Docker Engine | Linux| ✅ |
| Docker Desktop | Linux | ❌ |
| Docker Desktop | macOS | ❌ |

## FAQ 💬

### How do I use it?

  Very simple! These are the steps:

  - Set the `BOOT` variable to the [operating system](#how-do-i-select-the-operating-system) you want to install.

  - Start the container and connect to [port 8006](http://127.0.0.1:8006/) using your web browser.

  - You will see the screen and can now install the OS of your choice using your keyboard and mouse.

  Enjoy your brand new machine, and don't forget to star this repo!

### How do I select the operating system?

  You can use the `BOOT` environment variable in order to specify the operating system that will be downloaded:

  ```yaml
  environment:
    BOOT: "alpine"
  ```
  Select from the values below:
  
  | **Value**  | **Operating System** | **Size** |
  |---|---|---|
  | `alma`     | Alma Linux      | 1.7 GB  |
  | `alpine`   | Alpine Linux    | 60 MB    |
  | `cachy`    | CachyOS         | 2.6 GB   |
  | `centos`   | CentOS          | 6.4 GB   |
  | `debian`   | Debian          | 3.7 GB   |
  | `fedora`   | Fedora          | 2.9 GB   |
  | `gentoo`   | Gentoo          | 1.3 GB   |
  | `kali`     | Kali Linux      | 3.4 GB   |
  | `nixos`    | NixOS           | 2.4 GB   |
  | `suse`     | OpenSUSE        | 1.0 GB   |
  | `oracle`   | Oracle Linux    | 1.0 GB   |
  | `rocky`    | Rocky Linux     | 1.9 GB   |
  | `ubuntu`   | Ubuntu Desktop  | 3.3 GB   |
  | `ubuntus`  | Ubuntu Server   | 2.7 GB   |

### How can I use my own image?

  If you want to download an operating system that is not in the list above, you can set the `BOOT` variable to the URL of the image:

  ```yaml
  environment:
    BOOT: "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-virt-3.19.1-aarch64.iso"
  ```

  The `BOOT` URL accepts files in any of the following formats:

  | **Extension** | **Format**  |
  |---|---|
  | `.img`        | Raw         |
  | `.raw`        | Raw         |
  | `.iso`        | Optical     |
  | `.qcow2`      | QEMU        |
  | `.vmdk`       | VMware      |
  | `.vhd`        | VirtualPC   |
  | `.vhdx`       | Hyper-V     |
  | `.vdi`        | VirtualBox  |

   It will also accept files such as `.img.gz`, `.qcow2.xz`, `.iso.zip` and many more, because it will automaticly extract compressed files.

  Alternatively you can use a local image file directly, by binding it in your compose file:
  
  ```yaml
  volumes:
    - ./example.iso:/boot.iso
  ```

  This way you can supply either a `/boot.iso`, `/boot.img` or a `/boot.qcow2` file. The value of `BOOT` will be ignored in this case.

### How do I change the storage location?

  To change the storage location, include the following bind mount in your compose file:

  ```yaml
  volumes:
    - ./qemu:/storage
  ```

  Replace the example path `./qemu` with the desired storage folder or named volume.
  
### How do I change the size of the disk?

  To expand the default size of 16 GB, add the `DISK_SIZE` setting to your compose file and set it to your preferred capacity:

  ```yaml
  environment:
    DISK_SIZE: "128G"
  ```
  
> [!TIP]
> This can also be used to resize the existing disk to a larger capacity without any data loss.

### How do I change the amount of CPU or RAM?

  By default, the container will be allowed to use a maximum of 2 CPU cores and 2 GB of RAM.

  If you want to adjust this, you can specify the desired amount using the following environment variables:

  ```yaml
  environment:
    RAM_SIZE: "8G"
    CPU_CORES: "4"
  ```

### How do I increase the display resolution?

  For maximum compatibility, the display output will be a simple framebuffer by default. While this isn't the most optimal, it doesn't require any drivers.
  
  If your guest OS bundles the `virtio-gpu` driver (as most Linux distributions do), you can add the following to your compose file:

  ```yaml
  environment:
    VGA: "virtio-gpu"
  ```

  to add a virtual graphics cards to your machine that allows for higher resolutions.
  
> [!NOTE]
> Using this method your screen will stay black during the boot process, until the point where the driver is actually loaded.
 
### How do I boot Windows?

  Use [dockur/windows-arm](https://github.com/dockur/windows-arm) instead, as it includes all the drivers required during installation, amongst many other features.

### How do I boot x86/x64 images?

  You can use the [qemu](https://github.com/qemus/qemu/) container to run x86 and x64 images on ARM.

### How do I verify if my system supports KVM?

  Only Linux and Windows 11 support KVM virtualization, macOS and Windows 10 do not unfortunately.
  
  You can run the following commands in Linux to check your system:

  ```bash
  sudo apt install cpu-checker
  sudo kvm-ok
  ```

  If you receive an error from `kvm-ok` indicating that KVM cannot be used, please check whether:

  - the virtualization extensions (`Intel VT-x` or `AMD SVM`) are enabled in your BIOS.

  - you enabled "nested virtualization" if you are running the container inside a virtual machine.

  - you are not using a cloud provider, as most of them do not allow nested virtualization for their VPS's.

  If you do not receive any error from `kvm-ok` but the container still complains about KVM, please check whether:

  - you are not using "Docker Desktop for Linux" as it does not support KVM, instead make use of Docker Engine directly.
 
  - it could help to add `privileged: true` to your compose file (or `sudo` to your `docker run` command), to rule out any permission issue.

### How do I expose network ports?
 
   You can expose ports just by adding them to your compose file. If you want to be able to connect to the SSH service of the machine for example, you would add it like this:
   
   ```yaml
   ports:
     - 2222:22
   ```
 
   This will make port 2222 on your host redirect to port 22 of the virtual machine.

### How do I assign an individual IP address to the container?

  By default, the container uses bridge networking, which shares the IP address with the host. 

  If you want to assign an individual IP address to the container, you can create a macvlan network as follows:

  ```bash
  docker network create -d macvlan \
      --subnet=192.168.0.0/24 \
      --gateway=192.168.0.1 \
      --ip-range=192.168.0.100/28 \
      -o parent=eth0 vlan
  ```
  
  Be sure to modify these values to match your local subnet. 

  Once you have created the network, change your compose file to look as follows:

  ```yaml
  services:
    qemu:
      container_name: qemu
      ..<snip>..
      networks:
        vlan:
          ipv4_address: 192.168.0.100

  networks:
    vlan:
      external: true
  ```
 
  An added benefit of this approach is that you won't have to perform any port mapping anymore, since all ports will be exposed by default.

> [!IMPORTANT]  
> This IP address won't be accessible from the Docker host due to the design of macvlan, which doesn't permit communication between the two. If this is a concern, you need to create a [second macvlan](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/#host-access) as a workaround.

### How can the VM acquire an IP address from my router?

  After configuring the container for [macvlan](#how-do-i-assign-an-individual-ip-address-to-the-container), it is possible for the VM to become part of your home network by requesting an IP from your router, just like a real PC.

  To enable this mode, in which the container and the VM will have separate IP addresses, add the following lines to your compose file:

  ```yaml
  environment:
    DHCP: "Y"
  devices:
    - /dev/vhost-net
  device_cgroup_rules:
    - 'c *:* rwm'
  ```

### How do I add multiple disks?

  To create additional disks, modify your compose file like this:
  
  ```yaml
  environment:
    DISK2_SIZE: "32G"
    DISK3_SIZE: "64G"
  volumes:
    - ./example2:/storage2
    - ./example3:/storage3
  ```

### How do I pass-through a disk?

  It is possible to pass-through disk devices directly by adding them to your compose file in this way:

  ```yaml
  devices:
    - /dev/sdb:/disk1
    - /dev/sdc:/disk2
  ```

  Use `/disk1` if you want it to become your main drive, and use `/disk2` and higher to add them as secondary drives.

### How do I pass-through a USB device?

  To pass-through a USB device, first lookup its vendor and product id via the `lsusb` command, then add them to your compose file like this:

  ```yaml
  environment:
    ARGUMENTS: "-device usb-host,vendorid=0x1234,productid=0x1234"
  devices:
    - /dev/bus/usb
  ```

### How do I share files with the host?

  To share files with the host, first ensure that your guest OS has `9pfs` support compiled in or available as a kernel module. If so, add the following volume to your compose file:

  ```yaml
  volumes:
    - ./example:/shared
  ```

  Then start the container and execute the following command in the guest:

  ```shell
  mount -t 9p -o trans=virtio shared /mnt/example
  ```

  Now the `./example` directory on the host will be available as `/mnt/example` in the guest.

### How can I provide custom arguments to QEMU?

  You can create the `ARGUMENTS` environment variable to provide additional arguments to QEMU at runtime:

  ```yaml
  environment:
    ARGUMENTS: "-device usb-tablet"
  ```

  If you want to see the full command-line arguments used, you can set:

  ```yaml
  environment:
    DEBUG: "Y"
  ```

## Stars 🌟
[![Stars](https://starchart.cc/qemus/qemu-arm.svg?variant=adaptive)](https://starchart.cc/qemus/qemu-arm)

[build_url]: https://github.com/qemus/qemu-arm/
[hub_url]: https://hub.docker.com/r/qemux/qemu-arm/
[tag_url]: https://hub.docker.com/r/qemux/qemu-arm/tags
[pkg_url]: https://github.com/qemus/qemu-arm/pkgs/container/qemu-arm

[Build]: https://github.com/qemus/qemu-arm/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/qemux/qemu-arm/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/qemux/qemu-arm.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/qemux/qemu-arm/latest?arch=arm64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fqemus%2Fqemu-arm%2Fqemu-arm.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
