#!/system/bin/sh
# YLStackOS - Custom Linux Distro Installer for Android
# Main Installer Script - Interactive Mode
# Version: 1.0.0

set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS_DIR="/data/local/rootfs"
CONFIG_DIR="$ROOTFS_DIR/.ylstackos"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (su)"
        exit 1
    fi
}

check_android_version() {
    if [ ! -f /system/build.prop ]; then
        log_warn "Cannot verify Android version, assuming Android 12+"
        return 0
    fi
    
    local android_version=$(grep "ro.build.version.sdk" /system/build.prop | cut -d'=' -f2)
    if [ -z "$android_version" ]; then
        android_version=$(getprop ro.build.version.sdk)
    fi
    
    if [ "$android_version" -lt 12 ]; then
        log_warn "Android version < 12 detected, some features may not work"
    fi
    log_info "Android SDK version: $android_version"
}

create_directory_structure() {
    log_info "Creating directory structure..."
    mkdir -p "$ROOTFS_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/plugins"
    mkdir -p "$CONFIG_DIR/logs"
    mkdir -p "$CONFIG_DIR/cache"
    log_success "Directory structure created"
}

download_rootfs() {
    local distro="$1"
    local rootfs_path="$2"
    
    log_info "Downloading $distro rootfs..."
    
    case "$distro" in
        "parrot")
            local url="http://mirror.math.princeton.edu/pub/parrot/iso/5.3/Parrot-rootfs-5.3_arm64.tar.xz"
            ;;
        "kali-full")
            local url="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"
            ;;
        "kali-minimal")
            local url="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz"
            ;;
        "ubuntu")
            local url="https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-core-arm64.tar.gz"
            ;;
        "prebuilt")
            local url="https://github.com/downloads/ylstackos/rootfs/releases/latest/download/ylstackos-parrot-arm64.tar.xz"
            ;;
        *)
            log_error "Unknown distribution: $distro"
            return 1
            ;;
    esac
    
    local filename=$(basename "$url")
    local cache_path="$CONFIG_DIR/cache/$filename"
    
    if [ -f "$cache_path" ]; then
        log_info "Using cached rootfs: $cache_path"
        cp "$cache_path" "$rootfs_path/$filename"
    else
        log_info "Downloading from: $url"
        if command -v wget >/dev/null 2>&1; then
            wget -O "$rootfs_path/$filename" "$url"
        elif command -v curl >/dev/null 2>&1; then
            curl -L -o "$rootfs_path/$filename" "$url"
        else
            log_error "Neither wget nor curl found. Please install one of them."
            return 1
        fi
        cp "$rootfs_path/$filename" "$cache_path"
    fi
    
    log_success "Rootfs downloaded"
    return 0
}

extract_rootfs() {
    local rootfs_path="$1"
    local archive="$2"
    
    log_info "Extracting rootfs..."
    
    if [ ! -f "$archive" ]; then
        log_error "Archive not found: $archive"
        return 1
    fi
    
    cd "$rootfs_path"
    busybox tar -xpf "$archive" --numeric-owner
    
    log_success "Rootfs extracted to: $rootfs_path"
}

setup_ssh() {
    local rootfs_path="$1"
    local default_password="$2"
    
    log_info "Setting up SSH..."
    
    cat > "$rootfs_path/etc/resolv.conf" << EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    
    log_info "Installing OpenSSH..."
    busybox chroot "$rootfs_path" /bin/sh -c "apt-get update -qq"
    busybox chroot "$rootfs_path" /bin/sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-client openssh-server"
    
    log_info "Configuring SSH..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$rootfs_path/etc/ssh/sshd_config"
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$rootfs_path/etc/ssh/sshd_config"
    
    log_info "Setting root password..."
    echo "root:$default_password" | busybox chroot "$rootfs_path" /bin/sh -c "chpasswd"
    
    log_success "SSH configured with default password"
}

fix_groups() {
    local rootfs_path="$1"
    
    log_info "Fixing Android groups..."
    
    busybox chroot "$rootfs_path" /bin/sh -c "
        groupadd -g 3003 aid_inet 2>/dev/null || true
        groupadd -g 3004 aid_net_raw 2>/dev/null || true
        groupadd -g 1003 aid_graphics 2>/dev/null || true
        usermod -g 3003 -G 3003,3004 -a _apt 2>/dev/null || true
        usermod -G 3003 -a root 2>/dev/null || true
    "
    
    log_success "Groups fixed"
}

auto_update_upgrade() {
    local rootfs_path="$1"
    
    log_info "Running auto-update and upgrade..."
    
    busybox chroot "$rootfs_path" /bin/sh -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get upgrade -y -qq
        apt-get autoremove -y -qq
        apt-get clean
    "
    
    log_success "System updated and upgraded"
}

create_boot_script() {
    local rootfs_path="$1"
    local distro_name="$2"
    
    log_info "Creating boot script..."
    
    cat > "$ROOTFS_DIR/boot-$distro_name.sh" << 'BOOTSCRIPT'
#!/system/bin/sh

ROOTFS="/data/local/rootfs/DISTRO_PLACEHOLDER"

if [ ! -d "$ROOTFS" ]; then
    echo "[-] Rootfs not found at $ROOTFS"
    exit 1
fi

echo "[*] Setting up mounts for chroot..."

busybox mount -o bind $ROOTFS $ROOTFS
busybox mount -o remount,dev,suid /data

busybox mount --bind /dev $ROOTFS/dev
busybox mount --bind /sys $ROOTFS/sys
busybox mount --bind /proc $ROOTFS/proc
busybox mount -t devpts devpts $ROOTFS/dev/pts

busybox mount -t tmpfs -o mode=755 tmpfs $ROOTFS/sys/fs/cgroup
mkdir -p $ROOTFS/sys/fs/cgroup/devices
busybox mount -t cgroup -o devices cgroup $ROOTFS/sys/fs/cgroup/devices

if [ -d /dev/binderfs ]; then
    echo "[*] Binderfs detected, mounting into chroot..."
    mkdir -p $ROOTFS/dev/binderfs
    busybox mount -r -o bind /dev/binderfs $ROOTFS/dev/binderfs
fi

if [ -d /sdcard ]; then
    mkdir -p $ROOTFS/sdcard
    busybox mount --bind /sdcard $ROOTFS/sdcard
fi

echo "[*] Checking for external SD..."
for dir in /storage/*; do
    base=$(basename "$dir")
    if [ "$base" != "emulated" ] && [ "$base" != "self" ]; then
        if [ -d "$dir" ]; then
            echo "[+] Found external storage at $dir"
            mkdir -p $ROOTFS/external_sd
            busybox mount --bind "$dir" $ROOTFS/external_sd
            MOUNTED_EXTERNAL_SD=1
            break
        fi
    fi
done

echo "[*] Entering chroot..."
if [ -e "$ROOTFS/bin/sudo" ]; then
    busybox chroot $ROOTFS /bin/sudo su
else
    busybox chroot $ROOTFS /bin/su -
fi

echo "[*] Cleaning up mounts..."
if [ -d /dev/binderfs ]; then
    busybox umount -l $ROOTFS/dev/binderfs
fi

busybox umount $ROOTFS/dev/pts
busybox umount -l $ROOTFS/dev
busybox umount $ROOTFS/sys/fs/cgroup/devices
busybox umount $ROOTFS/sys/fs/cgroup
busybox umount $ROOTFS/sys
busybox umount $ROOTFS/proc
busybox umount $ROOTFS/sdcard 2>/dev/null

if [ "$MOUNTED_EXTERNAL_SD" = "1" ]; then
    busybox umount $ROOTFS/external_sd
fi

echo "[+] Done."
BOOTSCRIPT

    sed -i "s|DISTRO_PLACEHOLDER|$distro_name|g" "$ROOTFS_DIR/boot-$distro_name.sh"
    chmod +x "$ROOTFS_DIR/boot-$distro_name.sh"
    
    log_success "Boot script created: $ROOTFS_DIR/boot-$distro_name.sh"
}

save_config() {
    local config_file="$CONFIG_DIR/config.sh"
    
    cat > "$config_file" << EOF
#!/system/bin/sh
# YLStackOS Configuration
# Auto-generated

DISTRO_NAME="$1"
ROOTFS_PATH="$2"
DEFAULT_PASSWORD="$3"
AUTO_UPDATE="$4"
INSTALLED_PLUGINS="$5"
INSTALL_DATE="$(date)"
VERSION="$VERSION"
EOF
    
    chmod +x "$config_file"
    log_info "Configuration saved"
}

show_menu() {
    clear
    echo "========================================"
    echo "  YLStackOS Installer v$VERSION"
    echo "  Custom Linux for Android"
    echo "========================================"
    echo ""
    echo "Select Distribution:"
    echo "  1. Parrot Security OS (Full)"
    echo "  2. Kali Linux (Full)"
    echo "  3. Kali Linux (Minimal)"
    echo "  4. Ubuntu Base"
    echo "  5. Prebuilt (GitHub releases)"
    echo ""
    echo "  0. Exit"
    echo ""
}

get_user_choice() {
    show_menu
    printf "Enter choice [0-5]: "
    read choice
    
    case "$choice" in
        1) echo "parrot"; return 0 ;;
        2) echo "kali-full"; return 0 ;;
        3) echo "kali-minimal"; return 0 ;;
        4) echo "ubuntu"; return 0 ;;
        5) echo "prebuilt"; return 0 ;;
        0) echo "exit"; return 1 ;;
        *) echo "invalid"; return 2 ;;
    esac
}

get_password() {
    printf "Enter default root password: "
    read -s password
    echo ""
    if [ -z "$password" ]; then
        password="toor"
        log_warn "Using default password: toor"
    fi
    echo "$password"
}

get_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        printf "$prompt [y/n] (default: $default): "
        read answer
        case "$answer" in
            y|Y|yes|YES) echo "yes"; return 0 ;;
            n|N|no|NO) echo "no"; return 0 ;;
            "") echo "$default"; return 0 ;;
        esac
    done
}

install_plugins() {
    local rootfs_path="$1"
    local distro="$2"
    
    log_info "Plugin Installation Menu"
    echo "========================="
    echo ""
    
    local plugins_available=""
    if [ -d "$PLUGINS_DIR" ]; then
        plugins_available=$(ls -1 "$PLUGINS_DIR"/*.sh 2>/dev/null || echo "")
    fi
    
    if [ -z "$plugins_available" ]; then
        log_warn "No plugins available"
        return 0
    fi
    
    echo "Available Plugins:"
    local i=1
    for plugin in $plugins_available; do
        local plugin_name=$(basename "$plugin" .sh)
        echo "  $i. $plugin_name"
        i=$((i + 1))
    done
    echo "  0. Skip/Continue"
    echo ""
    
    printf "Select plugins to install (comma-separated, e.g. 1,2,3) [default: 1,2,3,4,5,6]: "
    read selection
    
    if [ "$selection" = "0" ]; then
        log_info "Skipping plugin installation"
        return 0
    fi
    
    if [ -z "$selection" ]; then
        selection="1 2 3 4 5 6"
        log_info "Installing default plugins: network-tools, auto-update, openssh, docker, vnc, tmate"
    fi
    
    local plugin_list=$(echo "$selection" | tr ',' ' ')
    i=1
    for plugin in $plugins_available; do
        for sel in $plugin_list; do
            if [ "$i" = "$sel" ]; then
                local plugin_name=$(basename "$plugin" .sh)
                log_info "Installing plugin: $plugin_name"
                (busybox chroot "$rootfs_path" /bin/sh "$plugin") || log_warn "Plugin $plugin_name failed"
            fi
        done
        i=$((i + 1))
    done
    
    log_success "Plugin installation complete"
}

main() {
    check_root
    check_android_version
    create_directory_structure
    
    local distro=$(get_user_choice)
    if [ "$distro" = "exit" ]; then
        log_info "Exiting..."
        exit 0
    fi
    
    while [ "$distro" = "invalid" ]; do
        distro=$(get_user_choice)
    done
    
    local distro_name="${distro}-arm64"
    local rootfs_path="$ROOTFS_DIR/$distro_name"
    
    log_info "Selected: $distro"
    
    local use_existing="no"
    if [ -d "$rootfs_path" ] && [ -n "$(ls -A "$rootfs_path" 2>/dev/null)" ]; then
        use_existing=$(get_yes_no "Rootfs already exists. Use existing?" "no")
    fi
    
    if [ "$use_existing" = "no" ]; then
        mkdir -p "$rootfs_path"
        
        local download_choice=$(get_yes_no "Download rootfs now?" "yes")
        if [ "$download_choice" = "yes" ]; then
            download_rootfs "$distro" "$rootfs_path"
            
            local archive=$(ls "$rootfs_path"/*.tar.* 2>/dev/null | head -1)
            if [ -n "$archive" ]; then
                extract_rootfs "$rootfs_path" "$archive"
            else
                log_error "No archive found to extract"
                exit 1
            fi
        else
            log_info "Please copy your rootfs archive to: $rootfs_path/"
            log_info "Then run this script again"
            exit 0
        fi
    fi
    
    local password=$(get_password)
    
    local setup_ssh_choice=$(get_yes_no "Setup SSH with default password?" "yes")
    if [ "$setup_ssh_choice" = "yes" ]; then
        setup_ssh "$rootfs_path" "$password"
        fix_groups "$rootfs_path"
    fi
    
    local update_choice=$(get_yes_no "Auto update and upgrade system?" "yes")
    if [ "$update_choice" = "yes" ]; then
        auto_update_upgrade "$rootfs_path"
    fi
    
    install_plugins "$rootfs_path" "$distro"
    
    create_boot_script "$rootfs_path" "$distro_name"
    
    save_config "$distro" "$rootfs_path" "$password" "$update_choice" ""
    
    echo ""
    echo "========================================"
    log_success "Installation Complete!"
    echo "========================================"
    echo ""
    echo "Boot command: sh $ROOTFS_DIR/boot-$distro_name.sh"
    echo "Default password: $password"
    echo ""
    echo "To start SSH server in chroot:"
    echo "  mkdir -p /run/sshd"
    echo "  service ssh start"
    echo ""
}

main "$@"