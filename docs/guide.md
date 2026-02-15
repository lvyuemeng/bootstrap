# Linux Bootstrap Guide

A systematic, distribution-agnostic approach to building Linux systems from the ground up.

---

## Core Philosophy

| Principle | Description |
|-----------|-------------|
| **Flat Modules** | No folders - all modules in one list |
| **Dependency-Driven** | Order determined by MODULE_REQUIRES |
| **Composable** | User selects modules, system resolves order |
| **Portable Config** | bootstrap.conf stored in user's dotfiles |

---

## Quick Start

### 1. Create bootstrap.conf

In your dotfiles repo (git, home-manager, chezmoi, etc.):

```bash
# bootstrap.conf
BOOTSTRAP_MODULES=(
    "dbus"
    "sway"
    "bluetooth-stack"
    "audio-pipewire"
    "network-manager"
)
```

### 2. Run Bootstrap

```bash
./bootstrap.sh install
```

That's it. The system:
- Resolves dependencies from MODULE_REQUIRES
- Installs in correct order
- Links your configs

---

## bootstrap.conf

The entry point for bootstrap. Store anywhere in your dotfiles.

```bash
# Modules to install (order doesn't matter - deps resolved automatically)
BOOTSTRAP_MODULES=(
    "dbus"
    "sway"
    "bluetooth-stack"
)

# Optional: custom config overrides
OVERRIDES=(
    "~/.config/sway/config"
    "~/.config/hypr/hyprland.conf"
)
```

---

## How Dependencies Work

Module declares what it needs:

```bash
# modules/sway.sh
MODULE_REQUIRES=("dbus" "wlroots")
```

System resolves automatically:

```
User requests: sway
System resolves: dbus → wlroots → sway
Installs in order: dbus → wlroots → sway
```

---

## Module System

### Available Modules

All modules are flat (no folders):

```
modules/
├── dbus.sh
├── udev.sh
├── sway.sh
├── i3.sh
├── hyprland.sh
├── audio-pipewire.sh
├── audio-pulseaudio.sh
├── bluetooth-stack.sh
├── network-manager.sh
├── polybar.sh
├── waybar.sh
├── dunst.sh
├── mako.sh
├── wofi.sh
├── kitty.sh
├── foot.sh
└── ...
```

### Creating a Module

```bash
# modules/my-module.sh
MODULE_NAME="my-module"
MODULE_DESCRIPTION="My custom module"

MODULE_REQUIRES=("dbus")

declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="package-name"
MODULE_PACKAGES[debian]="package-name"

module_install() {
    pkg_install "${MODULE_PACKAGES[$distro]}"
    # ... custom install steps
}

module_proofs() {
    proof_command "my-command"
}
```

---

## Configuration

### User Config Integration

Bootstrap links configs from your dotfiles:

1. Create config in your dotfiles (anywhere)
2. Add to OVERRIDES in bootstrap.conf:
   ```bash
   OVERRIDES=("~/.config/sway/config")
   ```

### Config Precedence

| Source | Priority |
|--------|----------|
| OVERRIDES in bootstrap.conf | Highest |
| ~/.config/<module>/ | Medium |
| Module defaults | Lowest |

---

## Bootstrap Commands

```bash
# Install all modules from bootstrap.conf
bootstrap install

# Install specific module (auto-resolves deps)
bootstrap install sway

# Verify installation
bootstrap verify [module]

# Show status
bootstrap status

# Reset state (force re-install)
bootstrap reset

# Show help
bootstrap help
```

---

## Debugging

```bash
# Check service status
systemctl status <service>
journalctl -u <service>

# Check proofs
bootstrap proof <module>

# Check deps resolution
bootstrap deps <module>
```

---

## Design Principles

1. **Flat modules** - No categorization, just a list
2. **Explicit deps** - MODULE_REQUIRES defines order
3. **User control** - bootstrap.conf is the entry point
4. **Portable** - Works with any dotfiles manager
