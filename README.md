# YLStackOS - Custom Linux for Android

## Overview

YLStackOS is an automation system for installing and running custom Linux distributions (Debian-based) on rooted Android devices via chroot. It provides an interactive installer, plugin system, SSH configuration, and auto-update functionality.

## Features

- **Interactive Installer** - Choose your preferred Linux distro
- **SSH Auto-Setup** - Pre-configured SSH with default password
- **Auto Update/Upgrade** - Keep your system updated
- **Plugin System** - Extend functionality with plugins
- **Boot Script** - Easy chroot environment launcher

## Supported Distributions

- Parrot Security OS
- Kali Linux (Full/Minimal)
- Ubuntu Base

## Quick Start

### 1. Transfer files to Android

Transfer all `.sh` files to your Android device (e.g., `/data/local/rootfs/`)

### 2. Run Installer

```bash
su
cd /data/local/rootfs
sh ylstackos-installer.sh
```

### 3. Follow Prompts

- Select distribution
- Set default root password
- Choose to install SSH
- Select plugins to install

### 4. Boot Linux

```bash
sh boot.sh
# OR
sh /data/local/rootfs/boot-<distro-name>.sh
```

### 5. Start SSH

```bash
mkdir -p /run/sshd
service ssh start
```

Connect via SSH:
- Host: `<device-ip>`
- Port: 22
- User: root
- Password: `<your-set-password>`

## Available Plugins

| Plugin | Description |
|--------|-------------|
| `openssh` | SSH server with security hardening |
| `tmate` | Remote terminal sharing |
| `docker` | Docker container runtime |
| `network-tools` | Nmap, netcat, tcpdump, etc. |
| `auto-update` | Auto update/upgrade system |
| `vnc` | VNC server for GUI access |

## Plugin Management

```bash
# List plugins
sh plugin-manager.sh list

# Install plugin
sh plugin-manager.sh install <plugin-name>

# Create new plugin
sh create-plugin.sh myplugin "My custom plugin"
```

## Custom Plugins

Create your own plugins using the template:

```bash
sh create-plugin.sh myplugin "Description"
```

Edit the plugin file to add your functionality.

## Auto-Update Commands

Inside chroot:
- `yls-update` - Update packages
- `yls-upgrade` - Full system upgrade
- `yls-check-updates` - Check for updates
- `yls-autoupdate` - Enable auto-update cron

## Project Structure

```
ylstackos/
├── ylstackos-installer.sh  # Main installer
├── boot.sh                 # Boot script
├── plugin-manager.sh       # Plugin manager
├── create-plugin.sh        # Plugin creator
├── plugins/
│   ├── plugin-base.sh      # Plugin base class
│   ├── openssh.sh          # SSH plugin
│   ├── tmate.sh            # Terminal sharing
│   ├── docker.sh           # Docker
│   ├── network-tools.sh    # Network tools
│   ├── auto-update.sh      # Auto-update
│   ├── vnc.sh              # VNC server
│   └── plugin-template.sh  # Plugin template
└── README.md
```

## Requirements

- Rooted Android device
- Android 12+
- Busybox installed

## Troubleshooting

### SSH Connection Refused
```bash
mkdir -p /run/sshd
service ssh start
```

### DNS Not Working
```bash
echo 'nameserver 1.1.1.1' > /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
```

### Package Install Errors
```bash
groupadd -g 3003 aid_inet
groupadd -g 3004 aid_net_raw
usermod -G 3003 -a root
```

## License

MIT License