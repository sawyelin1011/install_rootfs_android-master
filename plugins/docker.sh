#!/bin/sh
# Plugin: docker
# Docker container runtime
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="docker"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Docker container runtime for running containers"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Installing Docker..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_chroot "$ROOTFS" "apt-get update -qq"
plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-compose"

plugin_info "Creating Docker helper scripts..."

cat > "$ROOTFS/usr/local/bin/docker-init" << 'EOF'
#!/bin/sh
echo "Initializing Docker..."
mkdir -p /var/lib/docker
echo "Docker initialized. Use 'service docker start' to start."
EOF
chmod +x "$ROOTFS/usr/local/bin/docker-init"

cat > "$ROOTFS/usr/local/bin/docker-status" << 'EOF'
#!/bin/sh
if service docker status >/dev/null 2>&1; then
    echo "Docker is running"
    docker ps
else
    echo "Docker is not running"
    echo "Start with: service docker start"
fi
EOF
chmod +x "$ROOTFS/usr/local/bin/docker-status"

plugin_enable "$PLUGIN_NAME"

plugin_info "Docker plugin installed successfully"
echo "Init Docker: docker-init"
echo "Check status: docker-status"
echo "Start Docker: service docker start"