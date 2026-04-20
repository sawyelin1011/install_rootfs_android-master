#!/bin/sh
# Plugin: auto-update
# Auto update and upgrade system
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="auto-update"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Auto update and upgrade system packages"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Setting up auto-update..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_info "Creating update scripts..."

cat > "$ROOTFS/usr/local/bin/yls-update" << 'EOF'
#!/bin/sh
# YLStackOS Update Script

echo "========================================="
echo "  YLStackOS System Updater"
echo "========================================="
echo ""

echo "[*] Updating package lists..."
apt-get update -qq

echo "[*] Upgrading packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get upgrade -y -qq

echo "[*] Cleaning up..."
apt-get autoremove -y -qq
apt-get clean

echo ""
echo "[+] Update complete!"
echo "Last updated: $(date)"
EOF
chmod +x "$ROOTFS/usr/local/bin/yls-update"

cat > "$ROOTFS/usr/local/bin/yls-upgrade" << 'EOF'
#!/bin/sh
# YLStackOS Full Upgrade Script (includes distribution upgrade)

echo "========================================="
echo "  YLStackOS Full System Upgrade"
echo "========================================="
echo ""

echo "[*] Updating package lists..."
apt-get update -qq

echo "[*] Upgrading packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq

echo "[*] Cleaning up..."
apt-get autoremove -y -qq
apt-get clean

echo ""
echo "[+] Upgrade complete!"
echo "Last upgraded: $(date)"
EOF
chmod +x "$ROOTFS/usr/local/bin/yls-upgrade"

cat > "$ROOTFS/usr/local/bin/yls-autoupdate" << 'EOF'
#!/bin/sh
# Auto-update cron job setup

CRON_FILE="/etc/cron.d/ylstackos-update"

cat > "$CRON_FILE" << 'CRONEOF'
# YLStackOS Auto Update
# Run daily at 3 AM
0 3 * * * root /usr/local/bin/yls-update >> /var/log/ylstackos-update.log 2>&1
CRONEOF

echo "Auto-update configured to run daily at 3 AM"
echo "Log file: /var/log/ylstackos-update.log"
EOF
chmod +x "$ROOTFS/usr/local/bin/yls-autoupdate"

cat > "$ROOTFS/usr/local/bin/yls-check-updates" << 'EOF'
#!/bin/sh
# Check for available updates without installing

echo "Checking for available updates..."
echo ""

apt-get update -qq 2>/dev/null
UPGRADE_COUNT=$(apt-get -s upgrade | grep -c "^Inst " || true)

if [ -n "$UPGRADE_COUNT" ] && [ "$UPGRADE_COUNT" -gt 0 ]; then
    echo "[!] $UPGRADE_COUNT packages can be upgraded"
    echo ""
    echo "Run 'yls-update' to install updates"
    apt-get -s upgrade | grep "^Inst "
else
    echo "[+] System is up to date"
fi
EOF
chmod +x "$ROOTFS/usr/local/bin/yls-check-updates"

plugin_enable "$PLUGIN_NAME"

plugin_info "Auto-update plugin installed successfully"
echo "Update system: yls-update"
echo "Full upgrade: yls-upgrade"
echo "Check updates: yls-check-updates"
echo "Enable auto-update: yls-autoupdate"