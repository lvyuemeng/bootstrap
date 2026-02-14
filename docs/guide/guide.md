# Linux Bootstrap Guide

A systematic, distribution-agnostic approach to building Linux systems from the ground up.

---

## Core Philosophy

| Principle | Description |
|-----------|--------------|
| **Layered Construction** | Build your system in discrete, testable layers |
| **Distribution Agnostic** | Focus on underlying technologies, not distro-specific tools |
| **Minimal by Default** | Only add what you need, when you need it |
| **Understand Before Automate** | Learn the manual way first |

---

## The Seven Layers Model

Think of your Linux system as a stack:

```
┌─────────────────────────────────────┐
│  7. User Applications               │ ← Firefox, Office, Games
├─────────────────────────────────────┤
│  6. Desktop Environment / WM        │ ← GNOME, KDE, i3, Sway
├─────────────────────────────────────┤
│  5. Session & Display Management    │ ← Login, Display Servers
├─────────────────────────────────────┤
│  4. Hardware Services               │ ← Audio, Bluetooth, Network
├─────────────────────────────────────┤
│  3. System Services & Init          │ ← systemd, udev, dbus
├─────────────────────────────────────┤
│  2. Core System & Shell             │ ← bash, coreutils, filesystem
├─────────────────────────────────────┤
│  1. Kernel & Bootloader             │ ← Linux kernel, GRUB/systemd-boot
└─────────────────────────────────────┘
```

---

## Layer Details

### Layer 1-2: Foundation

**Kernel & Boot**
- Boot process: UEFI/BIOS → Bootloader → Kernel → Init
- Kernel modules: `lsmod`, `modprobe`, `/etc/modprobe.d/`
- Key files: `/boot/vmlinuz-*`, `/boot/initramfs-*`, `/boot/grub/grub.cfg`

**Core System**
- Shell, coreutils, package manager
- Essential directories: `/etc/`, `/usr/bin/`, `/usr/lib/`, `/var/`, `/home/`

### Layer 3: System Services

| Service | Purpose | Key Commands |
|---------|---------|--------------|
| **systemd** | Init system, service management | `systemctl` |
| **D-Bus** | Inter-process communication | `dbus-monitor` |
| **udev** | Device management | `udevadm` |

### Layer 4: Hardware Services

**Network Management** (choose ONE)
- NetworkManager (desktop-friendly)
- systemd-networkd (minimal, built-in)
- iwd (modern WiFi-only)

**Audio Stack**
```
Applications
     ↓
PipeWire (or PulseAudio)
     ↓
ALSA (kernel drivers)
```

**Bluetooth**: BlueZ stack

### Layer 5: Session & Display

**Display Servers**
- Wayland (modern, better security)
- X11/Xorg (traditional, universal compatibility)

**Login Managers**: LightDM, SDDM, GDM, ly

### Layer 6: Desktop/WM

**Full Desktop Environments**: GNOME, KDE Plasma, XFCE, Cinnamon

**Window Managers**
- Tiling: i3, Sway, bspwm, dwm
- Floating: Openbox, Fluxbox
- Dynamic: awesome, xmonad

---

## Configuration Hierarchy

| Scope | Location | Precedence |
|-------|----------|------------|
| User | `~/.config/`, `~/` | Highest |
| System | `/etc/` | Medium |
| Default | `/usr/lib/` | Lowest |

---

## Bootstrap Checklist

### Foundation (Layers 1-2)
- [ ] Bootloader installed and configured
- [ ] Kernel boots successfully
- [ ] Root filesystem mounted
- [ ] Basic utilities available
- [ ] Package manager working

### System Services (Layer 3)
- [ ] systemd running
- [ ] D-Bus service active
- [ ] udev managing devices

### Hardware Services (Layer 4)
- [ ] Network connected
- [ ] Audio working (PipeWire or PulseAudio)
- [ ] Bluetooth (if needed)

### Display & Session (Layer 5)
- [ ] Display server installed
- [ ] Login manager configured OR manual startx works

### Desktop/WM (Layer 6)
- [ ] Window manager or DE installed
- [ ] Applications available

---

## Debugging Commands

```bash
# Service status
systemctl status <service>
journalctl -u <service>

# Hardware
lspci          # PCI devices
lsusb          # USB devices
lsmod          # Kernel modules
ip link        # Network interfaces

# Logs
journalctl -b              # This boot
dmesg | grep -i <module>   # Kernel messages
```
