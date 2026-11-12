#!/usr/bin/env bash
# OpenWrt VM Installer ISO Builder
# Builds a bootable hybrid ISO (BIOS + UEFI) tailored for Virtual Machines.

set -euo pipefail

OPENWRT_VERSION="${OPENWRT_VERSION:-25.12.6}"
TARGET="x86"
SUBTARGET="64"
PROFILE="generic"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/.cache"
BUILD_DIR="${SCRIPT_DIR}/.build"
DIST_DIR="${SCRIPT_DIR}/dist"
FILES_DIR="${SCRIPT_DIR}/files"

DOWNLOAD_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}"
IB_ARCHIVE="openwrt-imagebuilder-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.zst"
IB_URL="${DOWNLOAD_BASE}/${IB_ARCHIVE}"
TARGET_IMG_GZ="openwrt-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}-generic-ext4-combined-efi.img.gz"
TARGET_IMG_URL="${DOWNLOAD_BASE}/${TARGET_IMG_GZ}"

# Extra packages for VM environment
VM_PACKAGES="luci parted sfdisk fdisk lsblk qemu-ga coreutils-dd resize2fs"

echo "=============================================================="
echo "          OpenWrt VM Installer ISO Build Pipeline"
echo "=============================================================="
echo "OpenWrt Version : ${OPENWRT_VERSION}"
echo "Target Platform : ${TARGET}/${SUBTARGET} (${PROFILE})"
echo "Extra Packages  : ${VM_PACKAGES}"
echo "Output Directory: ${DIST_DIR}"
echo "=============================================================="

mkdir -p "${CACHE_DIR}" "${BUILD_DIR}" "${DIST_DIR}" "${FILES_DIR}/opt/openwrt-install"

# Step 1: Download ImageBuilder
if [[ ! -f "${CACHE_DIR}/${IB_ARCHIVE}" ]]; then
    echo "-> Downloading OpenWrt Image Builder (${IB_ARCHIVE})..."
    curl --noproxy '*' -fSL --progress-bar "${IB_URL}" -o "${CACHE_DIR}/${IB_ARCHIVE}"
else
    echo "-> Using cached Image Builder: ${CACHE_DIR}/${IB_ARCHIVE}"
fi

# Step 2: Download Target disk image to embed into the installer
if [[ ! -f "${CACHE_DIR}/${TARGET_IMG_GZ}" ]]; then
    echo "-> Downloading OpenWrt combined-efi disk image (${TARGET_IMG_GZ})..."
    curl --noproxy '*' -fSL --progress-bar "${TARGET_IMG_URL}" -o "${CACHE_DIR}/${TARGET_IMG_GZ}"
else
    echo "-> Using cached target image: ${CACHE_DIR}/${TARGET_IMG_GZ}"
fi

# Copy target image into files overlay for embedding
cp "${CACHE_DIR}/${TARGET_IMG_GZ}" "${FILES_DIR}/opt/openwrt-install/openwrt-image.img.gz"

# Step 3: Extract Image Builder
IB_DIR="${BUILD_DIR}/openwrt-imagebuilder-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.Linux-x86_64"
if [[ ! -d "${IB_DIR}" ]]; then
    echo "-> Extracting Image Builder into build directory..."
    tar --zstd -xf "${CACHE_DIR}/${IB_ARCHIVE}" -C "${BUILD_DIR}"
fi

cd "${IB_DIR}"

# Step 4: Configure ISO generation
echo "-> Configuring ISO generation..."
if grep -q "CONFIG_ISO_IMAGES" .config; then
    sed -i 's/.*CONFIG_ISO_IMAGES.*/CONFIG_ISO_IMAGES=y/' .config
else
    echo "CONFIG_ISO_IMAGES=y" >> .config
fi

# Step 5: Customize GRUB ISO menu
echo "-> Customizing GRUB boot menu..."
cat << 'EOF' > target/linux/x86/image/grub-iso.cfg
@SERIAL_CONFIG@
@TERMINAL_CONFIG@

set default="0"
set timeout="5"

if [ "${grub_platform}" = "efi" ]; then
    set root='(cd0)'
else
    set root='(cd)'
fi

menuentry "Install OpenWrt to VM Disk (Interactive Installer)" {
	linux /boot/vmlinuz root=/dev/sr0 rootfstype=iso9660 rootwait @CMDLINE@ openwrt_installer=interactive noinitrd
}

menuentry "Install OpenWrt to VM Disk (Unattended Auto-Install)" {
	linux /boot/vmlinuz root=/dev/sr0 rootfstype=iso9660 rootwait @CMDLINE@ openwrt_installer=auto noinitrd
}

menuentry "OpenWrt Live System (Rescue Shell / RAM mode)" {
	linux /boot/vmlinuz root=/dev/sr0 rootfstype=iso9660 rootwait @CMDLINE@ noinitrd
}
EOF

# Ensure permissions on overlay scripts
chmod +x "${FILES_DIR}/usr/sbin/openwrt-install" 2>/dev/null || true
chmod +x "${FILES_DIR}/etc/profile.d/installer.sh" 2>/dev/null || true
chmod +x "${FILES_DIR}/etc/rc.local" 2>/dev/null || true
chmod +x "${FILES_DIR}/etc/uci-defaults/99-vm-defaults" 2>/dev/null || true

# Step 6: Build the ISO image
echo "-> Building OpenWrt VM Installer ISO with Image Builder..."
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    make image \
    PROFILE="${PROFILE}" \
    PACKAGES="${VM_PACKAGES}" \
    FILES="${FILES_DIR}"

# Step 7: Locate and copy output ISO
GENERATED_ISO="${IB_DIR}/bin/targets/${TARGET}/${SUBTARGET}/openwrt-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}-generic-image-efi.iso"
if [[ ! -f "${GENERATED_ISO}" ]]; then
    # Fallback if non-efi name used
    GENERATED_ISO="${IB_DIR}/bin/targets/${TARGET}/${SUBTARGET}/openwrt-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}-generic-image.iso"
fi

if [[ ! -f "${GENERATED_ISO}" ]]; then
    echo "ERROR: Failed to find generated ISO file!" >&2
    exit 1
fi

OUTPUT_ISO="${DIST_DIR}/openwrt-${OPENWRT_VERSION}-vm-installer-x86-64.iso"
LATEST_LINK="${DIST_DIR}/openwrt-vm-installer.iso"

cp "${GENERATED_ISO}" "${OUTPUT_ISO}"
ln -sf "$(basename "${OUTPUT_ISO}")" "${LATEST_LINK}"

echo ""
echo "=============================================================="
echo "                 Build Completed Successfully!                "
echo "=============================================================="
echo "Output ISO: ${OUTPUT_ISO}"
echo "Symlink   : ${LATEST_LINK}"
echo "Size      : $(du -h "${OUTPUT_ISO}" | cut -f1)"
echo "SHA256    :"
sha256sum "${OUTPUT_ISO}" | tee "${OUTPUT_ISO}.sha256"
echo "=============================================================="
