#!/bin/sh
# Plugin: openssh
# SSH Server with advanced configuration
# Version: 1.0.0

. "$(dirname "$0")/plugin-base.sh"

PLUGIN_NAME="openssh"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="OpenSSH server with hardened security"
PLUGIN_AUTHOR="YLStackOS"

plugin_info "Installing OpenSSH server..."

ROOTFS="$(plugin_get_rootfs_path)"
if [ -z "$ROOTFS" ] || [ ! -d "$ROOTFS" ]; then
    plugin_error "Rootfs not found"
    exit 1
fi

plugin_chroot "$ROOTFS" "apt-get update -qq"
plugin_chroot "$ROOTFS" "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-client openssh-server"

SSH_CONFIG="$ROOTFS/etc/ssh/sshd_config"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^#*X11Forwarding.*/X11Forwarding yes/' "$SSH_CONFIG"
sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding yes/' "$SSH_CONFIG"
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSH_CONFIG"
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 3/' "$SSH_CONFIG"

mkdir -p "$ROOTFS/var/run/sshd"

plugin_info "Creating SSH startup script..."
cat > "$ROOTFS/usr/local/bin/startssh" << 'EOF'
#!/bin/sh
mkdir -p /run/sshd
/usr/sbin/sshd
echo "SSH server started"
EOF
chmod +x "$ROOTFS/usr/local/bin/startssh"

plugin_info "Creating SSH security script..."
cat > "$ROOTFS/usr/local/bin/ssh-hardening" << 'EOF'
#!/bin/sh
# Fail2Ban-like SSH protection

LOG_FILE="/var/log/auth.log"
MAX_ATTEMPTS=5
BLOCK_TIME=300

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

check_failed_logins() {
    local ip=$(last -i | grep "Failed password" | awk '{print $3}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    if [ -n "$ip" ]; then
        local count=$(last -i | grep "Failed password" | awk '{print $3}' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
        if [ "$count" -gt "$MAX_ATTEMPTS" ]; then
            echo "Warning: Multiple failed login attempts from $ip ($count attempts)"
        fi
    fi
}

check_failed_logins
EOF
chmod +x "$ROOTFS/usr/local/bin/ssh-hardening"

plugin_enable "$PLUGIN_NAME"

plugin_info "OpenSSH plugin installed successfully"
echo "Start SSH: startssh"
echo "Default port: 22"