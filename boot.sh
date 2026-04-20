#!/system/bin/sh
# YLStackOS Boot Script
# Launch Linux chroot environment on Android
# Version: 1.0.0

VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

show_banner() {
    echo ""
    echo -e "${CYAN}========================================"
    echo "  YLStackOS Boot Loader v$VERSION"
    echo "========================================${NC}"
    echo ""
}

select_distro() {
    local rootfs_base="/data/local/rootfs"
    
    echo "Available distributions:"
    echo ""
    
    local i=1
    local distros=""
    for dir in "$rootfs_base"/*; do
        if [ -d "$dir" ]; then
            local name=$(basename "$dir")
            if [ -d "$dir/bin" ] || [ -d "$dir/usr" ]; then
                echo "  $i. $name"
                distros="$distros $name"
                i=$((i + 1))
            fi
        fi
    done
    
    if [ "$i" -eq 1 ]; then
        log_error "No distributions found in $rootfs_base"
        exit 1
    fi
    
    echo ""
    printf "Select distribution [1]: "
    read selection
    
    if [ -z "$selection" ]; then
        selection=1
    fi
    
    i=1
    for name in $distros; do
        if [ "$i" -eq "$selection" ]; then
            ROOTFS="$rootfs_base/$name"
            return 0
        fi
        i=$((i + 1))
    done
    
    log_error "Invalid selection"
    exit 1
}

setup_mounts() {
    log_info "Setting up mounts for chroot..."
    
    if [ ! -d "$ROOTFS" ]; then
        log_error "Rootfs not found at $ROOTFS"
        exit 1
    fi
    
    busybox mount -o bind "$ROOTFS" "$ROOTFS"
    busybox mount -o remount,dev,suid /data
    
    busybox mount --bind /dev "$ROOTFS/dev"
    busybox mount --bind /sys "$ROOTFS/sys"
    busybox mount --bind /proc "$ROOTFS/proc"
    busybox mount -t devpts devpts "$ROOTFS/dev/pts"
    
    busybox mount -t tmpfs -o mode=755 tmpfs "$ROOTFS/sys/fs/cgroup"
    mkdir -p "$ROOTFS/sys/fs/cgroup/devices"
    busybox mount -t cgroup -o devices cgroup "$ROOTFS/sys/fs/cgroup/devices"
    
    if [ -d /dev/binderfs ]; then
        log_info "Binderfs detected, mounting into chroot..."
        mkdir -p "$ROOTFS/dev/binderfs"
        busybox mount -r -o bind /dev/binderfs "$ROOTFS/dev/binderfs"
    fi
    
    if [ -d /sdcard ]; then
        mkdir -p "$ROOTFS/sdcard"
        busybox mount --bind /sdcard "$ROOTFS/sdcard"
    fi
    
    log_info "Checking for external SD..."
    for dir in /storage/*; do
        base=$(basename "$dir")
        if [ "$base" != "emulated" ] && [ "$base" != "self" ]; then
            if [ -d "$dir" ]; then
                log_info "Found external storage at $dir"
                mkdir -p "$ROOTFS/external_sd"
                busybox mount --bind "$dir" "$ROOTFS/external_sd"
                MOUNTED_EXTERNAL_SD=1
                break
            fi
        fi
    done
    
    log_success "Mounts ready"
}

enter_chroot() {
    log_info "Entering chroot..."
    echo ""
    
    if [ -e "$ROOTFS/bin/sudo" ]; then
        busybox chroot "$ROOTFS" /bin/sudo su
    else
        busybox chroot "$ROOTFS" /bin/su -
    fi
}

cleanup_mounts() {
    log_info "Cleaning up mounts..."
    
    if [ -d /dev/binderfs ]; then
        busybox umount -l "$ROOTFS/dev/binderfs"
    fi
    
    busybox umount "$ROOTFS/dev/pts" 2>/dev/null || true
    busybox umount -l "$ROOTFS/dev" 2>/dev/null || true
    busybox umount "$ROOTFS/sys/fs/cgroup/devices" 2>/dev/null || true
    busybox umount "$ROOTFS/sys/fs/cgroup" 2>/dev/null || true
    busybox umount "$ROOTFS/sys" 2>/dev/null || true
    busybox umount "$ROOTFS/proc" 2>/dev/null || true
    busybox umount "$ROOTFS/sdcard" 2>/dev/null || true
    
    if [ "$MOUNTED_EXTERNAL_SD" = "1" ]; then
        busybox umount "$ROOTFS/external_sd" 2>/dev/null || true
    fi
    
    log_success "Cleanup complete"
}

main() {
    check_root
    show_banner
    
    if [ -n "$1" ]; then
        ROOTFS="/data/local/rootfs/$1"
    else
        select_distro
    fi
    
    if [ ! -d "$ROOTFS" ]; then
        log_error "Rootfs not found: $ROOTFS"
        exit 1
    fi
    
    log_info "Starting: $(basename "$ROOTFS")"
    
    setup_mounts
    
    enter_chroot
    
    cleanup_mounts
    
    log_success "Session ended"
}

trap cleanup_mounts EXIT

main "$@"