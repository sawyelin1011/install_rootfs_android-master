#!/bin/sh
# Plugin: tmate
# Remote shell sharing via tmate
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="tmate"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Share your terminal session remotely"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Installing tmate..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_chroot "$ROOTFS" "apt-get update -qq"
plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tmate"

plugin_info "Creating tmate wrapper script..."
cat > "$ROOTFS/usr/local/bin/tmate-share" << 'EOF'
#!/bin/sh
echo "Starting tmate session..."
echo "Share the session URL with anyone to give them terminal access"
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait-session -t main
EOF
chmod +x "$ROOTFS/usr/local/bin/tmate-share"

plugin_info "Creating tmate status script..."
cat > "$ROOTFS/usr/local/bin/tmate-status" << 'EOF'
#!/bin/sh
tmate -S /tmp/tmate.sock display-message -p "#{tmate_ssh}"
tmate -S /tmp/tmate.sock display-message -p "#{tmate_web}"
EOF
chmod +x "$ROOTFS/usr/local/bin/tmate-status"

plugin_enable "$PLUGIN_NAME"

plugin_info "tmate plugin installed successfully"
echo "Share terminal: tmate-share"
echo "Get session URL: tmate-status"