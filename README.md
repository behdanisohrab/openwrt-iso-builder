# openwrt-iso-builder

Tools to build a bootable OpenWrt ISO for VMs like Proxmox, VMware, VirtualBox, and QEMU.

It creates a hybrid BIOS and UEFI ISO that boots up, writes OpenWrt onto the virtual disk, expands the ext4 filesystem to take up the full virtual drive space, and configures networking as a DHCP client so it grabs an IP on your local subnet (such as 192.168.100.x).

## Build

Requires curl, tar, zstd, mkisofs or xorriso, and mtools.

```sh
./build.sh
```

Output is saved to `dist/openwrt-vm-installer.iso`.

## Usage

Mount the ISO in your VM and start it up. Run `openwrt-install` in the console (or boot unattended mode). It detects the virtual drive, flashes the image, resizes the partition and rootfs, and sets up DHCP client mode.

Once finished, remove the ISO and restart the VM. The console displays the assigned IP and the LuCI webpanel URL (`http://<ip>`).

## Test

Quick test using QEMU:

```sh
./test-vm.sh
```
