#!/system/bin/sh
# YLStackOS Non-Interactive Installer
# For use with GitHub Actions or automated setups
# Usage: nonint-install.sh <distro> <password>
# Version: 1.0.0

DISTRO="${1:-parrot}"
PASSWORD="${2:-toor}"
ROOTFS="/data/local/rootfs/$DISTRO-arm64"

echo "[*] YLStackOS Install: $DISTRO"

mkdir -p "$ROOTFS"

cd /sdcard/Download

if [ -f "ylstackos-$DISTRO-arm64.tar.xz" ]; then
    echo "[*] Extracting prebuilt rootfs..."
    busybox tar -xpf "ylstackos-$DISTRO-arm64.tar.xz" -C "$ROOTFS" --numeric-owner
elif [ -f "rootfs.tar.xz" ]; then
    echo "[*] Extracting rootfs..."
    busybox tar -xpf rootfs.tar.xz -C "$ROOTFS" --numeric-owner
else
    echo "[-] No rootfs found in /sdcard/Download/"
    exit 1
fi

echo "[*] Configuring..."
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$ROOTFS/etc/resolv.conf"

busybox chroot "$ROOTFS" /bin/sh -c "
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server net-tools
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    echo 'root:$PASSWORD' | chpasswd
    mkdir -p /run/sshd
    groupadd -g 3003 aid_inet 2>/dev/null || true
"

echo "[*] Creating boot script..."
cat > "/data/local/rootfs/boot-$DISTRO.sh" << BOOTEOF
#!/system/bin/sh
ROOTFS="$ROOTFS"
busybox mount -o bind \$ROOTFS \$ROOTFS
busybox mount -o remount,dev,suid /data
busybox mount --bind /dev \$ROOTFS/dev
busybox mount --bind /sys \$ROOTFS/sys
busybox mount --bind /proc \$ROOTFS/proc
busybox mount -t devpts devpts \$ROOTFS/dev/pts
busybox mount -t tmpfs -o mode=755 tmpfs \$ROOTFS/sys/fs/cgroup
mkdir -p \$ROOTFS/sys/fs/cgroup/devices
busybox mount -t cgroup -o devices cgroup \$ROOTFS/sys/fs/cgroup/devices
busybox chroot \$ROOTFS /bin/su -
busybox umount \$ROOTFS/dev/pts
busybox umount -l \$ROOTFS/dev
busybox umount \$ROOTFS/sys/fs/cgroup/devices
busybox umount \$ROOTFS/sys/fs/cgroup
busybox umount \$ROOTFS/sys
busybox umount \$ROOTFS/proc
BOOTEOF
chmod +x "/data/local/rootfs/boot-$DISTRO.sh"

echo "[+] Done!"
echo "Boot: /data/local/rootfs/boot-$DISTRO.sh"
echo "Password: $PASSWORD"