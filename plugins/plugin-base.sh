#!/bin/sh
# YLStackOS Plugin System
# Base Plugin Class and Utilities
# Version: 1.0.0

PLUGIN_API_VERSION="1.0.0"

plugin_log() {
    local level="$1"
    shift
    echo "[PLUGIN:$level] $*"
}

plugin_info() {
    plugin_log "INFO" "$@"
}

plugin_warn() {
    plugin_log "WARN" "$@"
}

plugin_error() {
    plugin_log "ERROR" "$@"
}

plugin_require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        plugin_error "This plugin must be run as root"
        return 1
    fi
}

plugin_check_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        plugin_warn "Command '$cmd' not found, skipping related functionality"
        return 1
    fi
    return 0
}

plugin_apt_install() {
    local packages="$1"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq $packages 2>/dev/null
}

plugin_get_rootfs_path() {
    if [ -n "$ROOTFS_PATH" ]; then
        echo "$ROOTFS_PATH"
        return 0
    fi
    
    local config="/data/local/rootfs/.ylstackos/config.sh"
    if [ -f "$config" ]; then
        . "$config"
        echo "$ROOTFS_PATH"
        return 0
    fi
    
    echo "/data/local/rootfs"
    return 1
}

plugin_chroot() {
    local rootfs_path="$1"
    shift
    busybox chroot "$rootfs_path" /bin/sh -c "$@"
}

plugin_file_exists() {
    local rootfs_path="$1"
    local file="$2"
    [ -e "$rootfs_path/$file" ]
}

plugin_read_json() {
    local file="$1"
    local key="$2"
    
    if [ -f "$file" ]; then
        grep "\"$key\"" "$file" | sed 's/.*"\('$key'\)": *"\([^"]*\)".*/\2/'
    fi
}

plugin_write_json() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if [ -f "$file" ]; then
        sed -i "s/\"$key\": \"[^\"]*\"/\"$key\": \"$value\"/" "$file"
    fi
}

plugin_register() {
    local name="$1"
    local version="$2"
    local description="$3"
    local author="$4"
    
    cat > "${PLUGIN_DIR:-./}/metadata.json" << EOF
{
    "name": "$name",
    "version": "$version",
    "description": "$description",
    "author": "$author",
    "api_version": "$PLUGIN_API_VERSION",
    "dependencies": [],
    "installed": false,
    "install_date": null
}
EOF
}

plugin_enable() {
    local plugin_name="$1"
    local enabled_plugins="/data/local/rootfs/.ylstackos/enabled_plugins"
    
    mkdir -p "$(dirname "$enabled_plugins")"
    if ! grep -q "^$plugin_name$" "$enabled_plugins" 2>/dev/null; then
        echo "$plugin_name" >> "$enabled_plugins"
    fi
}

plugin_disable() {
    local plugin_name="$1"
    local enabled_plugins="/data/local/rootfs/.ylstackos/enabled_plugins"
    
    if [ -f "$enabled_plugins" ]; then
        sed -i "/^$plugin_name$/d" "$enabled_plugins"
    fi
}

plugin_is_enabled() {
    local plugin_name="$1"
    local enabled_plugins="/data/local/rootfs/.ylstackos/enabled_plugins"
    
    [ -f "$enabled_plugins" ] && grep -q "^$plugin_name$" "$enabled_plugins"
}

plugin_call_hook() {
    local hook_name="$1"
    local rootfs_path="$2"
    
    local hooks_dir="/data/local/rootfs/.ylstackos/plugins/hooks"
    
    if [ -d "$hooks_dir" ]; then
        for hook_script in "$hooks_dir/${hook_name}_"*".sh"; do
            if [ -f "$hook_script" ]; then
                plugin_info "Running hook: $(basename "$hook_script")"
                (busybox chroot "$rootfs_path" /bin/sh "$hook_script") || true
            fi
        done
    fi
}