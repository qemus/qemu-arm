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

- Runs virtual machines inside a Docker container
- Automatic downloads for popular ARM64 Linux distributions
- Supports almost every disk and image format
- Web-based viewer for controlling the VM
- Near-native performance with KVM acceleration
- Customizable CPU, memory, and storage allocation
- Dynamic memory allocation with memory ballooning
- USB passthrough and host folder sharing
- Supports bridge, user-mode, macvlan, and macvtap networking

## Usage  🐳

##### Docker Compose:

```yaml
services:
  qemu:
    container_name: qemu
    image: qemux/qemu-arm
    environment:
      BOOT: "ubuntu"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
    volumes:
      - ./qemu:/storage
    restart: always
    stop_grace_period: 2m
```

##### Docker CLI:

```bash
docker run -it --rm --name qemu -e "BOOT=ubuntu" -p 8006:8006 --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -v "${PWD:-.}/qemu:/storage" --stop-timeout 120 docker.io/qemux/qemu-arm
```

##### Kubernetes:

```shell
kubectl apply -f https://raw.githubusercontent.com/qemus/qemu-arm/refs/heads/master/kubernetes.yml
```

##### GitHub Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/qemus/qemu-arm)

## Requirements ⚙️

  - A Linux host with KVM support, or Docker Desktop / Podman on Windows 11 with nested virtualization enabled.
  - At least 2 GB of RAM available.
  - At least 64 GB of free disk space.

> [!NOTE]
> Docker Desktop on macOS and Windows 10 do not currently provide the required KVM support for this image.

## FAQ 💬

### How do I use it?

  Very simple! These are the steps:

  - Set the `BOOT` variable to the [operating system](#how-do-i-select-the-operating-system) you want to install.

  - Start the container and connect to [port 8006](http://127.0.0.1:8006/) using your web browser.

  - Complete the installation using the web-based viewer.

  Enjoy your brand new machine, and don't forget to star this repo!

### How do I select the operating system?

  You can use the `BOOT` environment variable in order to specify the operating system that will be downloaded:

  ```yaml
  environment:
    BOOT: "ubuntu"
  ```
  Select from the values below:
  
  | **Value**  | **Operating System** | **Size** |
  |---|---|---|
  | `alma`     | Alma Linux      | 1.7 GB  |
  | `alpine`   | Alpine Linux    | 60 MB   |
  | `cachy`    | CachyOS         | 2.6 GB  |
  | `centos`   | CentOS          | 6.4 GB  |
  | `debian`   | Debian          | 3.7 GB  |
  | `fedora`   | Fedora          | 2.9 GB  |
  | `gentoo`   | Gentoo          | 1.3 GB  |
  | `kali`     | Kali Linux      | 3.4 GB  |
  | `nixos`    | NixOS           | 2.4 GB  |
  | `suse`     | OpenSUSE        | 1.0 GB  |
  | `rocky`    | Rocky Linux     | 1.9 GB  |
  | `ubuntu`   | Ubuntu Desktop  | 3.3 GB  |
  | `ubuntus`  | Ubuntu Server   | 2.7 GB  |

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

   It will also accept files such as `.img.gz`, `.qcow2.xz`, `.iso.zip` and many more, because it will automatically extract compressed files.

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

  To expand the default size of 64 GB, add the `DISK_SIZE` setting to your compose file and set it to your preferred capacity:

  ```yaml
  environment:
    DISK_SIZE: "128G"
  ```
  
> [!TIP]
> This can also be used to resize an existing disk to a larger capacity without any data loss. However, you will need to manually extend the disk partition afterwards inside your OS, since the added disk space will appear as unallocated.

### How do I change the amount of CPU or RAM?

  By default, the VM will be allowed to use 2 CPU cores and 2 GB of RAM.

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
> Using this method, your screen will stay black during the initial boot process, until the point where the driver is actually loaded.
 
### How do I boot Windows?

  Use [dockur/windows-arm](https://github.com/dockur/windows-arm) instead, as it includes all the drivers required during installation, amongst many other features.

### How do I boot x86/x64 images?

  You can use the [qemu](https://github.com/qemus/qemu/) container to run x86 and x64 images on ARM.

### How do I verify if my system supports KVM?

  First check if your software is compatible using this chart:

  | **Product**  | **Linux** | **Win11** | **Win10** | **macOS** |
  |---|---|---|---|---|
  | Docker CLI        | ✅   | ✅       | ❌        | ❌ |
  | Docker Desktop    | ❌   | ✅       | ❌        | ❌ | 
  | Podman CLI        | ✅   | ✅       | ❌        | ❌ | 
  | Podman Desktop    | ✅   | ✅       | ❌        | ❌ | 

  After that you can run the following commands in Linux to check your system:

  ```bash
  sudo apt install cpu-checker
  sudo kvm-ok
  ```

  If you receive an error from `kvm-ok` indicating that KVM cannot be used, please check whether:

  - the virtualization extensions (`Intel VT-x` or `AMD SVM`) are enabled in your BIOS.

  - you enabled "nested virtualization" if you are running the container inside a virtual machine.

  - you are not using a cloud provider, as most of them do not allow nested virtualization for their VPSs.

  If you did not receive any error from `kvm-ok` but the container still complains about a missing KVM device, it could help to add `privileged: true` to your compose file (or `sudo` to your `docker` command) to rule out any permission issue.

### How do I expose network ports?

  When using bridge networking, you can expose ports by adding them to your compose file. If you want to be able to connect to the SSH service of the machine for example, you would add it like this:

  ```yaml
  ports:
    - 2222:22
  ```

  This will make port 2222 on your host redirect to port 22 of the virtual machine.

  When using user-mode networking (for example when running under Podman), you will also need to add those ports to the `USER_PORTS` variable like this:

  ```yaml
  environment:
    USER_PORTS: "22,80,443"
  ```

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

### How do I pass through a disk?

  You can pass through disk devices or partitions directly by adding them to your compose file in this way:

  ```yaml
  devices:
    - /dev/sdb:/disk1
    - /dev/sdc1:/disk2
  ```

  Use `/disk1` if you want it to become your main drive, and use `/disk2` and higher to add them as secondary drives.

### How do I pass through a USB device?

  To pass through a USB device, first look up its vendor and product IDs via the `lsusb` command, then add them to your compose file like this:

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

### How do I enable dynamic memory allocation?

  By default, the VM is allocated the full amount of RAM configured via `RAM_SIZE` for its entire lifetime.

  However, you can enable [memory ballooning](dynamic.md) if you want the container to dynamically reclaim unused guest RAM based on host memory pressure.

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

### Can I also run Proxmox as a container?

  Yes, if you prefer a web-based management interface, or some advanced features that this container may not offer, you can try out [dockur/proxmox](https://github.com/dockur/proxmox).

## Stars 🌟
[![Stargazers](https://raw.githubusercontent.com/star-stats/stars/refs/heads/data/charts/qemus-qemu-arm.svg)](https://github.com/qemus/qemu-arm/stargazers)

[build_url]: https://github.com/qemus/qemu-arm/
[hub_url]: https://hub.docker.com/r/qemux/qemu-arm/
[tag_url]: https://hub.docker.com/r/qemux/qemu-arm/tags
[pkg_url]: https://github.com/qemus/qemu-arm/pkgs/container/qemu-arm

[Build]: https://github.com/qemus/qemu-arm/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/qemux/qemu-arm/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/qemux/qemu-arm.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/qemux/qemu-arm/latest?arch=arm64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fqemus%2Fqemu-arm%2Fqemu-arm.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
