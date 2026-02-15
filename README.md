# Bootstrap

A modular, dependency-based approach to building Linux systems from atomic components.

## Motive

Traditional bootstrap approaches treat Linux system setup as monolithic—you get a "desktop environment" that installs 200+ packages with unknown dependencies, no way to swap components, and no understanding of what's happening under the hood.

**Bootstrap** solves this by providing **atomic, composable modules**:
- Each component is independent
- Explicit dependencies
- Provable requirements
- Mix and match to build exactly what you need

## Introduction

Bootstrap is a distribution-agnostic framework for building Linux systems from the ground up. It uses a flat module system where each module defines its own dependencies, and the system automatically resolves the correct installation order.

Store your `bootstrap.conf` in your dotfiles (git, home-manager, chezmoi, etc.) for portable, reproducible system configurations.

## Features

- **Flat Modules** — No folders, no categories. All modules in one list.
- **Dependency-Driven** — Order determined by `MODULE_REQUIRES`, not folder structure.
- **Composable** — User selects modules, system resolves order automatically.
- **Portable Config** — `bootstrap.conf` stored in your dotfiles.
- **Multi-Distro** — Supports Arch, Debian, Fedora, and more.
- **Multi-Init** — Works with systemd, openrc, runit.
- **Verification** — Built-in proof system to verify installations.

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/lvyuemeng/bootstrap.git
cd bootstrap
```

### 2. Create bootstrap.conf

In your dotfiles repository, create `bootstrap.conf`:

```bash
# bootstrap.conf
MODULES=(
    "dbus"
    "udev"
    "sway"
    "bluetooth-stack"
    "audio-pipewire"
    "network-manager"
)

# Optional: custom config overrides
OVERRIDES=(
    "~/.config/sway/config"
)
```

### 3. Run Bootstrap

```bash
./bootstrap.sh install
```

That's it. The system:
- Resolves dependencies from `MODULE_REQUIRES`
- Installs in correct order
- Links your configs

## Usage

### Commands

```bash
# Install all modules from bootstrap.conf
./bootstrap.sh install

# Install specific module (auto-resolves deps)
./bootstrap.sh install sway

# Show dependency tree
./bootstrap.sh deps sway

# Verify installation
./bootstrap.sh verify [module]

# Run proof checks
./bootstrap.sh proof <module>

# Show status
./bootstrap.sh status

# Reset state (force re-install)
./bootstrap.sh reset

# Show help
./bootstrap.sh help
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BOOTSTRAP_DIR` | (auto) | Bootstrap installation directory |
| `TARGET_ROOT` | `/` | Target system root |
| `TARGET_USER` | (current) | Target user |

## Module System

### Available Modules

| Category | Modules |
|----------|---------|
| **Core** | dbus, udev, polkit, wayland |
| **Window Managers** | i3, sway, hyprland, niri, river, labwc, openbox |
| **Audio** | audio-pipewire, audio-pulseaudio, audio-alsa |
| **GPU** | gpu-intel, gpu-amd, gpu-nvidia |
| **Network** | network-manager |
| **Bluetooth** | bluetooth-stack |
| **Terminal** | kitty, foot |
| **Status Bars** | polybar (X11), waybar (Wayland) |
| **Notifications** | dunst (X11), mako (Wayland) |
| **Launchers** | wofi |
| **Clipboard** | clipman, wl-paste, xclip, xsel |

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

### Module Contract

Each module must define:

```bash
MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

# Dependencies (required)
MODULE_REQUIRES=("dbus" "kernel:btusb")
MODULE_OPTIONAL=("audio-pipewire")

# What this module provides
MODULE_PROVIDES=("bluetooth:daemon")

# Distribution-specific packages
declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="package-name"
MODULE_PACKAGES[debian]="package-name"

# Installation function
module_install() { ... }

# Verification function
module_proofs() { ... }
```

## Configuration

### User Config Integration

Bootstrap links configs from your dotfiles:

1. Create config in your dotfiles (anywhere)
2. Add to `OVERRIDES` in `bootstrap.conf`:
   ```bash
   OVERRIDES=("~/.config/sway/config")
   ```

### Config Precedence

| Source | Priority |
|--------|----------|
| OVERRIDES in bootstrap.conf | Highest |
| ~/.config/<module>/ | Medium |
| Module defaults | Lowest |

## API Reference

### File Operations

```bash
config_link "source" "target"           # Symlink file
config_link_dir "source" "target"       # Symlink directory
config_copy "source" "target"           # Copy file
config_copy_dir "source" "target"       # Copy directory
config_backup "file" [backup_dir]      # Backup file
config_exists "path"                    # Check existence
config_is_link "path"                   # Check if symlink
config_ensure_dir "path"                # Ensure directory exists
```

### Proof Functions

```bash
proof_command "cmd"              # Check command exists
proof_process "name"            # Check process running
proof_service_active "svc"      # Check systemd service
proof_dbus_service "name"       # Check D-Bus service
proof_kernel_module "mod"       # Check kernel module
proof_file "path"               # Check file exists
```

### Distro Functions

```bash
distro=$(distro_detect)    # Detect: arch, debian, fedora
init=$(init_detect)        # Detect: systemd, openrc, runit

pkg_install "packages"    # Install packages
pkg_remove "packages"     # Remove packages

svc_enable "service"       # Enable service
svc_start "service"        # Start service
svc_stop "service"         # Stop service
svc_status "service"       # Check service status
```

### Dependency Functions

```bash
deps_resolve "module1" "module2"    # Resolve dependencies
deps_order "module1" "module2"      # Return installation order
deps_check "module"                 # Check if dependencies met
```

### State Functions

```bash
state_load        # Load state from bootstrap.state.json
state_save        # Save current state
state_get "module"  # Get state for specific module
state_set "module" "installed"  # Set module state
```

## Debugging

```bash
# Check service status
systemctl status <service>
journalctl -u <service>

# Check proofs
./bootstrap.sh proof <module>

# Check deps resolution
./bootstrap.sh deps <module>

# Verify all modules
./bootstrap.sh verify
```

## License

MIT License - see [license](license) file for details.

---

Built with the philosophy of **flat modules**, **explicit dependencies**, and **user control**.
