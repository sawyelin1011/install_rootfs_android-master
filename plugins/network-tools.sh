#!/bin/sh
# Plugin: network-tools
# Network analysis and utilities
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="network-tools"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Network analysis tools (nmap, netcat, wireshark-cli, etc)"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Installing network tools..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_chroot "$ROOTFS" "apt-get update -qq"
plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq net-tools nmap netcat-openbsd iproute2 tcpdump dnsutils traceroute whois curl wget"

plugin_info "Creating network tools wrapper..."
cat > "$ROOTFS/usr/local/bin/net-scan" << 'EOF'
#!/bin/sh
echo "Network Scanner - Quick local network scan"
echo "=========================================="
ip route | grep default | awk '{print $3}' | xargs -I {} nmap -sn {} /24
EOF
chmod +x "$ROOTFS/usr/local/bin/net-scan"

cat > "$ROOTFS/usr/local/bin/net-portscan" << 'EOF'
#!/bin/sh
TARGET="${1:-localhost}"
PORTS="${2:-1-1000}"
echo "Scanning ports on $TARGET..."
nmap -p "$PORTS" "$TARGET"
EOF
chmod +x "$ROOTFS/usr/local/bin/net-portscan"

cat > "$ROOTFS/usr/local/bin/net-interfaces" << 'EOF'
#!/bin/sh
echo "Network Interfaces:"
ip addr show
echo ""
echo "Routes:"
ip route show
echo ""
echo "Connections:"
ss -tunap
EOF
chmod +x "$ROOTFS/usr/local/bin/net-interfaces"

plugin_enable "$PLUGIN_NAME"

plugin_info "Network tools plugin installed successfully"
echo "Quick scan: net-scan"
echo "Port scan: net-portscan <target> <ports>"
echo "Show interfaces: net-interfaces"