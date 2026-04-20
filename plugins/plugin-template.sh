#!/bin/sh
# YLStackOS Plugin Template
# Use this as a base to create your own plugins
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="template"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Your plugin description here"
PLUGIN_AUTHOR="Your Name"
PLUGIN_DEPENDENCIES=""

plugin_info "Installing $PLUGIN_NAME plugin..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

check_dependencies() {
    local deps="$PLUGIN_DEPENDENCIES"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            plugin_info "Installing dependency: $dep"
            plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $dep"
        fi
    done
}

do_install() {
    plugin_info "Doing installation steps..."
    
    # Example: Install packages
    # plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq package1 package2"
    
    # Example: Create scripts
    # cat > "$ROOTFS/usr/local/bin/my-script" << 'EOF'
    # #!/bin/sh
    # echo "Hello from plugin!"
    # EOF
    # chmod +x "$ROOTFS/usr/local/bin/my-script"
    
    # Example: Modify config files
    # echo "config=value" >> "$ROOTFS/etc/myapp.conf"
    
    plugin_info "Installation complete"
}

do_configure() {
    plugin_info "Configuring plugin..."
    # Add configuration steps here
    :
}

do_verify() {
    plugin_info "Verifying installation..."
    # Add verification steps here
    :
}

check_dependencies
do_install
do_configure
do_verify

plugin_enable "$PLUGIN_NAME"

plugin_info "$PLUGIN_NAME plugin installed successfully"
echo "Plugin: $PLUGIN_NAME v$PLUGIN_VERSION"
echo "$PLUGIN_DESCRIPTION"