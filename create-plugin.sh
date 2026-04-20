#!/bin/sh
# YLStackOS Plugin Creator
# Generate new plugin from template
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

if [ -z "$1" ]; then
    echo "Usage: $0 <plugin-name> [description]"
    echo ""
    echo "Example: $0 myplugin 'My custom plugin description'"
    exit 1
fi

PLUGIN_NAME="$1"
PLUGIN_DESCRIPTION="${2:-Custom plugin for YLStackOS}"
PLUGIN_FILE="$PLUGINS_DIR/${PLUGIN_NAME}.sh"

if [ -f "$PLUGIN_FILE" ]; then
    echo "Error: Plugin '$PLUGIN_NAME' already exists"
    exit 1
fi

cat > "$PLUGIN_FILE" << EOF
#!/bin/sh
# Plugin: $PLUGIN_NAME
# $PLUGIN_DESCRIPTION
# Version: 1.0.0

. "\$(dirname "\$0")/plugin-base.sh"

PLUGIN_NAME="$PLUGIN_NAME"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="$PLUGIN_DESCRIPTION"
PLUGIN_AUTHOR="Your Name"
PLUGIN_DEPENDENCIES=""

plugin_info "Installing \$PLUGIN_NAME plugin..."

ROOTFS="\$(plugin_get_rootfs_path)"
if [ -z "\$ROOTFS" ] || [ ! -d "\$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

check_dependencies() {
    local deps="\$PLUGIN_DEPENDENCIES"
    for dep in \$deps; do
        if ! command -v "\$dep" >/dev/null 2>&1; then
            plugin_info "Installing dependency: \$dep"
            plugin_chroot "\$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \$dep"
        fi
    done
}

do_install() {
    plugin_info "Installing \$PLUGIN_NAME..."
    
    # Add your installation steps here
    # Example: Install packages
    # plugin_chroot "\$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq package1 package2"
    
    # Example: Create configuration files
    # cat > "\$ROOTFS/etc/myapp.conf" << 'CONFIGEOF'
    # # Configuration
    # setting=value
    # CONFIGEOF
    
    # Example: Create helper scripts
    # cat > "\$ROOTFS/usr/local/bin/myapp" << 'SCRIPTEOF'
    # #!/bin/sh
    # echo "Hello from \$PLUGIN_NAME"
    # SCRIPTEOF
    # chmod +x "\$ROOTFS/usr/local/bin/myapp"
    
    plugin_success "Installation complete"
}

do_configure() {
    plugin_info "Configuring \$PLUGIN_NAME..."
    
    # Add configuration steps here
    :
}

do_verify() {
    plugin_info "Verifying installation..."
    
    # Add verification steps here
    # Example: Check if command exists
    # if ! command -v myapp >/dev/null 2>&1; then
    #     plugin_error "Failed to verify installation"
    #     return 1
    # fi
    
    :
}

check_dependencies
do_install
do_configure
do_verify

plugin_enable "\$PLUGIN_NAME"

plugin_info "\$PLUGIN_NAME plugin installed successfully"
echo "Plugin: \$PLUGIN_NAME v\$PLUGIN_VERSION"
echo "\$PLUGIN_DESCRIPTION"
EOF

chmod +x "$PLUGIN_FILE"

echo "Plugin created: $PLUGIN_FILE"
echo ""
echo "Edit the plugin file to add your functionality:"
echo "  $PLUGIN_FILE"
echo ""
echo "Then install with:"
echo "  su -c './plugin-manager.sh install $PLUGIN_NAME'"