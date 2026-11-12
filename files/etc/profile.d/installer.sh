#!/bin/sh
# Shell welcome banner and installer launcher

if [ -n "$SSH_CONNECTION" ]; then
    # Do not auto-launch in SSH sessions
    return 0 2>/dev/null || exit 0
fi

MY_TTY=$(tty 2>/dev/null | tr '/' '_' || echo "console")
if [ -f "/tmp/.installer_prompt_shown${MY_TTY}" ]; then
    return 0 2>/dev/null || exit 0
fi
touch "/tmp/.installer_prompt_shown${MY_TTY}"

echo ""
echo "=============================================================="
echo "          OpenWrt VM Installer & Live Rescue ISO"
echo "=============================================================="
echo "  To install OpenWrt onto this VM's virtual hard drive:"
echo "      openwrt-install"
echo ""
echo "  For automated installation:"
echo "      openwrt-install --auto"
echo ""
CURRENT_IP=$(ip -4 -o addr show br-lan 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
fi
if [ -n "$CURRENT_IP" ]; then
    echo "  Assigned IP Address : $CURRENT_IP"
    echo "  LuCI Web Interface  : http://$CURRENT_IP"
else
    echo "  Network Mode        : DHCP Client (run 'ip addr show' to view IP)"
fi
echo "=============================================================="
echo ""

if grep -q "openwrt_installer=interactive" /proc/cmdline 2>/dev/null; then
    echo "Starting OpenWrt VM Installer in 3 seconds (Press Ctrl+C for shell)..."
    sleep 3
    /usr/sbin/openwrt-install
fi
