#!/bin/sh
# Plugin: vnc
# VNC Server for GUI access
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="vnc"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="VNC server for GUI desktop access"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Installing VNC server..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_chroot "$ROOTFS" "apt-get update -qq"
plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tigervnc-standalone-server tigervnc-common x11vnc xvfb"

plugin_info "Creating VNC helper scripts..."

cat > "$ROOTFS/usr/local/bin/vnc-start" << 'EOF'
#!/bin/sh
# Start VNC server

PORT="${1:-5901}"
DISPLAY_NUM="${2:-1}"

echo "Starting VNC server on port $PORT (display :$DISPLAY_NUM)..."

vncserver :$DISPLAY_NUM -geometry 1280x720 -depth 24 -localhost
echo "VNC server started on port $PORT"
echo "Connect with: vncviewer localhost:$PORT"
EOF
chmod +x "$ROOTFS/usr/local/bin/vnc-start"

cat > "$ROOTFS/usr/local/bin/vnc-stop" << 'EOF'
#!/bin/sh
# Stop VNC server

DISPLAY_NUM="${1:-1}"
vncserver -kill :$DISPLAY_NUM
echo "VNC server stopped"
EOF
chmod +x "$ROOTFS/usr/local/bin/vnc-stop"

cat > "$ROOTFS/usr/local/bin/vnc-web" << 'EOF'
#!/bin/sh
# Start noVNC web interface

PORT="${1:-6080}"
DISPLAY_NUM="${1:-1}"

echo "Starting noVNC web interface on port $PORT..."

x11vnc -display :$DISPLAY_NUM -shared -forever -bg -httpport $PORT
echo "Access VNC via web: http://localhost:$PORT"
EOF
chmod +x "$ROOTFS/usr/local/bin/vnc-web"

cat > "$ROOTFS/usr/local/bin/vnc-status" << 'EOF'
#!/bin/sh
# Check VNC status

echo "VNC Server Status:"
vncserver -list
echo ""
echo "Active VNC connections:"
lsof -i :5900-5910 2>/dev/null || netstat -tlnp 2>/dev/null | grep -E "590[0-9]"
EOF
chmod +x "$ROOTFS/usr/local/bin/vnc-status"

plugin_enable "$PLUGIN_NAME"

plugin_info "VNC plugin installed successfully"
echo "Start VNC: vnc-start [port] [display]"
echo "Stop VNC: vnc-stop [display]"
echo "Web VNC: vnc-web [port]"
echo "Check status: vnc-status"