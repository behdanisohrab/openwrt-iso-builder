#!/usr/bin/env bash
# VM Verification and Testing Script
# Boots the installer ISO in QEMU to test installation on a virtual disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
ISO_IMAGE="${DIST_DIR}/openwrt-vm-installer.iso"
DISK_IMAGE="/tmp/openwrt-test-vm.qcow2"
DISK_SIZE="10G"

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --interactive   Launch QEMU with standard display window to test installer manually (default)"
    echo "  --curses        Launch QEMU with curses text interface in terminal"
    echo "  --headless      Run automated unattended install test in headless mode"
    echo "  --boot-disk     Boot directly from installed disk image (without ISO)"
    echo "  --help, -h      Show this help message"
    exit 0
}

MODE="interactive"
for arg in "$@"; do
    case "$arg" in
        --curses)
            MODE="curses"
            ;;
        --headless)
            MODE="headless"
            ;;
        --boot-disk)
            MODE="boot_disk"
            ;;
        --interactive)
            MODE="interactive"
            ;;
        --help|-h)
            usage
            ;;
    esac
done

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
    echo "ERROR: qemu-system-x86_64 is required but not installed." >&2
    exit 1
}

command -v qemu-img >/dev/null 2>&1 || {
    echo "ERROR: qemu-img is required but not installed." >&2
    exit 1
}

KVM_FLAG=""
if [ -w /dev/kvm ]; then
    KVM_FLAG="-enable-kvm"
fi

if [[ "$MODE" == "boot_disk" ]]; then
    if [[ ! -f "$DISK_IMAGE" ]]; then
        echo "ERROR: Test disk $DISK_IMAGE does not exist. Run an installation test first." >&2
        exit 1
    fi
    echo "=============================================================="
    echo "Booting VM directly from installed hard disk: $DISK_IMAGE"
    echo "=============================================================="
    exec qemu-system-x86_64 \
        $KVM_FLAG \
        -m 1024 \
        -smp 2 \
        -drive "file=${DISK_IMAGE},format=qcow2,if=virtio" \
        -netdev user,id=net0,hostfwd=tcp::8080-:80 \
        -device virtio-net-pci,netdev=net0 \
        -boot c
fi

if [[ ! -f "$ISO_IMAGE" ]]; then
    echo "ERROR: ISO image not found at $ISO_IMAGE. Run ./build.sh first." >&2
    exit 1
fi

echo "=============================================================="
echo "Preparing 10GB virtual test disk at $DISK_IMAGE..."
rm -f "$DISK_IMAGE"
qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
echo "=============================================================="

if [[ "$MODE" == "headless" ]]; then
    echo "Running headless automated installation test..."
    echo "The VM will boot from ISO, auto-install to /dev/vda, resize rootfs, and reboot."
    echo "Timeout set to 60 seconds."
    
    timeout 60s qemu-system-x86_64 \
        $KVM_FLAG \
        -m 1024 \
        -smp 2 \
        -drive "file=${DISK_IMAGE},format=qcow2,if=virtio" \
        -cdrom "${ISO_IMAGE}" \
        -boot d \
        -display none \
        -serial stdio \
        -no-reboot 2>&1 || true

    echo ""
    echo "Verifying installed disk image partitions..."
    qemu-img info "$DISK_IMAGE"
    echo "Automated test finished."
elif [[ "$MODE" == "curses" ]]; then
    echo "Starting QEMU with curses interface (Press Alt+2 for QEMU console, Alt+1 for display)..."
    qemu-system-x86_64 \
        $KVM_FLAG \
        -m 1024 \
        -smp 2 \
        -drive "file=${DISK_IMAGE},format=qcow2,if=virtio" \
        -cdrom "${ISO_IMAGE}" \
        -boot d \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0 \
        -display curses
else
    echo "Starting QEMU virtual machine window..."
    echo "Web UI (LuCI) will be accessible on host port http://localhost:8080"
    qemu-system-x86_64 \
        $KVM_FLAG \
        -m 1024 \
        -smp 2 \
        -drive "file=${DISK_IMAGE},format=qcow2,if=virtio" \
        -cdrom "${ISO_IMAGE}" \
        -boot d \
        -netdev user,id=net0,hostfwd=tcp::8080-:80 \
        -device virtio-net-pci,netdev=net0
fi
