#!/bin/bash
# YLStackOS Quick ADB Installer
# Run from computer: adb push installer.sh /data/local/tmp/ && adb shell su -c "sh /data/local/tmp/installer.sh"
# Version: 1.0.0

set -e

DISTRO="${1:-parrot}"
PASSWORD="${2:-toor}"
INSTALL_PLUGINS="${3:-yes}"

echo "========================================="
echo "  YLStackOS Quick Install"
echo "  Distro: $DISTRO"
echo "  Password: $PASSWORD"
echo "========================================="
echo ""

ROOTFS="/data/local/rootfs/$DISTRO-arm64"

echo "[*] Creating directories..."
mkdir -p "$ROOTFS"

echo "[*] Downloading rootfs..."
cd /sdcard/Download

case "$DISTRO" in
    parrot)
        wget -q -O rootfs.tar.xz http://mirror.math.princeton.edu/pub/parrot/iso/5.3/Parrot-rootfs-5.3_arm64.tar.xz
        ;;
    kali-full)
        wget -q -O rootfs.tar.xz https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz
        ;;
    kali-minimal)
        wget -q -O rootfs.tar.xz https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz
        ;;
    ubuntu)
        wget -q -O rootfs.tar.xz https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-core-arm64.tar.gz
        ;;
    prebuilt)
        wget -q -O rootfs.tar.xz https://github.com/ylstackos/releases/latest/download/ylstackos-parrot-arm64.tar.xz
        ;;
    *)
        echo "Unknown distro: $DISTRO"
        exit 1
        ;;
esac

echo "[*] Extracting rootfs..."
busybox tar -xpf rootfs.tar.xz -C "$ROOTFS" --numeric-owner

echo "[*] Configuring DNS..."
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$ROOTFS/etc/resolv.conf"

echo "[*] Installing SSH and network tools..."
busybox chroot "$ROOTFS" /bin/sh -c "
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-client openssh-server net-tools nmap netcat-openbsd iproute2 tcpdump dnsutils curl wget
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo 'root:$PASSWORD' | chpasswd
    mkdir -p /run/sshd
    groupadd -g 3003 aid_inet 2>/dev/null || true
    groupadd -g 3004 aid_net_raw 2>/dev/null || true
    usermod -G 3003 -a root 2>/dev/null || true
"

echo "[*] Creating boot script..."
cat > "/data/local/rootfs/boot-$DISTRO-arm64.sh" << 'BOOTEOF'
#!/system/bin/sh
ROOTFS="/data/local/rootfs/DISTRO-arm64"
busybox mount -o bind $ROOTFS $ROOTFS
busybox mount -o remount,dev,suid /data
busybox mount --bind /dev $ROOTFS/dev
busybox mount --bind /sys $ROOTFS/sys
busybox mount --bind /proc $ROOTFS/proc
busybox mount -t devpts devpts $ROOTFS/dev/pts
busybox mount -t tmpfs -o mode=755 tmpfs $ROOTFS/sys/fs/cgroup
mkdir -p $ROOTFS/sys/fs/cgroup/devices
busybox mount -t cgroup -o devices cgroup $ROOTFS/sys/fs/cgroup/devices
if [ -d /sdcard ]; then
    mkdir -p $ROOTFS/sdcard
    busybox mount --bind /sdcard $ROOTFS/sdcard
fi
busybox chroot $ROOTFS /bin/su -
busybox umount $ROOTFS/dev/pts
busybox umount -l $ROOTFS/dev
busybox umount $ROOTFS/sys/fs/cgroup/devices
busybox umount $ROOTFS/sys/fs/cgroup
busybox umount $ROOTFS/sys
busybox umount $ROOTFS/proc
busybox umount $ROOTFS/sdcard
BOOTEOF
sed -i "s/DISTRO/$DISTRO/g" "/data/local/rootfs/boot-$DISTRO-arm64.sh"
chmod +x "/data/local/rootfs/boot-$DISTRO-arm64.sh"

echo "[*] Adding update script..."
busybox chroot "$ROOTFS" /bin/sh -c "
    cat > /usr/local/bin/yls-update << 'UPEOF'
#!/bin/sh
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
apt-get autoremove -y -qq
apt-get clean
UPEOF
    chmod +x /usr/local/bin/yls-update
"

echo ""
echo "========================================="
echo "[+] Installation Complete!"
echo "========================================="
echo ""
echo "Boot: sh /data/local/rootfs/boot-$DISTRO-arm64.sh"
echo "SSH: root@<IP> -p 22"
echo "Password: $PASSWORD"
echo ""