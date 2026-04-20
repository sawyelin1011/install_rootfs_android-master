#!/system/bin/sh
# YLStackOS Plugin Manager
# Manage plugins - install, uninstall, list, enable, disable
# Version: 1.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
CONFIG_DIR="/data/local/rootfs/.ylstackos"
ROOTFS_PATH=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }

load_config() {
    if [ -f "$CONFIG_DIR/config.sh" ]; then
        . "$CONFIG_DIR/config.sh"
        ROOTFS_PATH="$ROOTFS_PATH"
    fi
}

set_rootfs() {
    if [ -n "$1" ]; then
        ROOTFS_PATH="$1"
    else
        load_config
        if [ -z "$ROOTFS_PATH" ]; then
            ROOTFS_PATH="/data/local/rootfs"
        fi
    fi
    export ROOTFS_PATH
}

list_plugins() {
    log_info "Available Plugins:"
    echo ""
    
    local i=1
    for plugin in "$PLUGINS_DIR"/*.sh; do
        if [ -f "$plugin" ]; then
            local name=$(basename "$plugin" .sh)
            local enabled="[ ]"
            
            if [ -f "$CONFIG_DIR/plugins/enabled" ]; then
                if grep -q "^$name$" "$CONFIG_DIR/plugins/enabled" 2>/dev/null; then
                    enabled="[✓]"
                fi
            fi
            
            echo "  $enabled $name"
            i=$((i + 1))
        fi
    done
    
    echo ""
}

install_plugin() {
    local plugin_name="$1"
    local plugin_file="$PLUGINS_DIR/${plugin_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        log_error "Plugin not found: $plugin_name"
        return 1
    fi
    
    log_info "Installing plugin: $plugin_name"
    
    (busybox chroot "$ROOTFS_PATH" /bin/sh "$plugin_file") || {
        log_error "Plugin installation failed"
        return 1
    }
    
    mkdir -p "$CONFIG_DIR/plugins"
    echo "$plugin_name" >> "$CONFIG_DIR/plugins/enabled" 2>/dev/null || true
    
    log_success "Plugin installed: $plugin_name"
}

uninstall_plugin() {
    local plugin_name="$1"
    
    if [ -f "$CONFIG_DIR/plugins/enabled" ]; then
        sed -i "/^${plugin_name}$/d" "$CONFIG_DIR/plugins/enabled"
    fi
    
    log_success "Plugin uninstalled: $plugin_name"
}

enable_plugin() {
    local plugin_name="$1"
    
    mkdir -p "$CONFIG_DIR/plugins"
    if ! grep -q "^${plugin_name}$" "$CONFIG_DIR/plugins/enabled" 2>/dev/null; then
        echo "$plugin_name" >> "$CONFIG_DIR/plugins/enabled"
    fi
    
    log_success "Plugin enabled: $plugin_name"
}

disable_plugin() {
    local plugin_name="$1"
    
    if [ -f "$CONFIG_DIR/plugins/enabled" ]; then
        sed -i "/^${plugin_name}$/d" "$CONFIG_DIR/plugins/enabled"
    fi
    
    log_success "Plugin disabled: $plugin_name"
}

show_help() {
    cat << EOF
YLStackOS Plugin Manager v1.0.0

Usage: $(basename "$0") <command> [options]

Commands:
    list                    List all available plugins
    install <plugin>        Install a plugin
    uninstall <plugin>      Uninstall a plugin
    enable <plugin>         Enable a plugin
    disable <plugin>        Disable a plugin
    set-rootfs <path>       Set the rootfs path
    help                    Show this help

Examples:
    $(basename "$0") list
    $(basename "$0") install openssh
    $(basename "$0") uninstall tmate
    $(basename "$0") set-rootfs /data/local/rootfs/parrot-arm64

EOF
}

main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        list)
            list_plugins
            ;;
        install)
            set_rootfs "$@"
            install_plugin "$1"
            ;;
        uninstall)
            uninstall_plugin "$1"
            ;;
        enable)
            enable_plugin "$1"
            ;;
        disable)
            disable_plugin "$1"
            ;;
        set-rootfs)
            set_rootfs "$1"
            log_info "Rootfs path set to: $ROOTFS_PATH"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"