# Architecture

## Overview

A modular, dependency-based approach to building Linux systems from atomic components.

---

## The Core Problem

Traditional approaches treat bootstrap as monolithic:
```
❌ BAD: "Install desktop environment" 
   → Installs 200+ packages
   → Unknown dependencies
   → Can't swap components
   → Can't understand what's happening
```

We need **atomic, composable modules**:
```
✓ GOOD: Each component is independent
   → Explicit dependencies
   → Provable requirements
   → Mix and match
   → Build exactly what you need
```

---

## Module System

### Module Structure

```
modules/
├── core/           # System services
│   ├── dbus.sh
│   └── udev.sh
├── hardware/       # Hardware support
│   ├── bluetooth-stack.sh
│   ├── audio-pipewire.sh
│   └── network-manager.sh
├── display/        # Display servers
│   ├── x11-server.sh
│   └── wayland-compositor.sh
├── session/        # Session management
│   ├── login-manager.sh
│   └── polkit.sh
└── desktop/        # Desktop components
    ├── window-manager/
    │   ├── i3.sh
    │   ├── sway.sh
    │   └── openbox.sh
    ├── panel/
    │   └── polybar.sh
    └── widgets/
        └── dunst.sh
```

### Module Contract

Each module must define:

```bash
MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

# Requirements (dependencies)
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

### Module Functions

| Function | Purpose |
|----------|---------|
| `module_install()` | Install packages, configure, start services |
| `module_verify()` | Post-install verification |
| `module_proofs()` | Proof verification chain |
| `module_info()` | Post-install guidance |

---

## Core Libraries

### config.sh - Configuration Management

File system primitives for dotfiles integration:

```bash
config_link "source" "target"           # Symlink file
config_link_dir "source" "target"       # Symlink directory
config_find "module-name"               # Discover user config
autostart_add "command"                 # Add to autostart
```

### proof.sh - Verification Framework

Atomic verification primitives for bottom-to-top proof chains.

```bash
proof_process "bluetoothd"              # Check process running
proof_service_active "bluetooth"         # Check systemd service
proof_kernel_module "btusb"              # Check kernel module
proof_dbus_service "org.bluez"           # Check D-Bus service
proof_command "nmcli"                    # Check command available
proof_verify_chain "bluetooth-stack" "dbus" "init"
```

### distro.sh - Distribution Adaptation

Cross-distribution package and service management.

```bash
distro=$(distro_detect)      # arch, debian, fedora, etc.
init=$(init_detect)          # systemd, openrc, runit, etc.

pkg_install "package-name"   # Install packages
svc_enable "servicename"     # Enable service
svc_start "servicename"      # Start service
```

### core.sh - Module Orchestration

Module loading and dependency resolution.

```bash
load_module "module-name"           # Load module
install_module "module-name"        # Install with verification
bootstrap "config-file"            # Run bootstrap workflow
```

---

## Bootstrap CLI

```bash
# Install a module
./bootstrap.sh install <module>

# Verify installation
./bootstrap.sh verify [module]

# Run proof checks
./bootstrap.sh proof <module>

# Verify dependency chain
./bootstrap.sh chain <module>

# Manage dotfiles
./bootstrap.sh dotfiles init|link|status

# Show status
./bootstrap.sh status

# Reset proof state
./bootstrap.sh reset
```

---

## User Config Integration

Bootstrap discovers user configs in portable locations:

| Location | Description |
|----------|-------------|
| `~/.dotfiles/<module>/` | git-based dotfiles |
| `~/.config/<module>/` | direct config |
| `~/.config/chezmoi/home_<module>` | chezmoi source |
| `~/.config/bootstrap/overrides/<module>` | bootstrap override |

**Module behavior:**
1. Check if user has config in dotfiles
2. If yes: link to it
3. If no: widget creates default on first run

---

## Data Flow

```
User Command
     │
     ▼
bootstrap.sh
     │
     ▼
core.sh (orchestration)
     │
     ├─► Load modules/*.sh
     │
     ├─► distro.sh (detect system)
     │
     ├─► config.sh (link user configs)
     │
     ├─► proof.sh (verify requirements)
     │
     └─► Install packages → Start services
```

---

## Extending the Framework

### Adding Distributions

Edit `lib/distro.sh`:
- Add detection in `distro_detect()`
- Add package commands in `pkg_install()`
- Add service commands in `svc_enable()`

### Adding Modules

Create `modules/new-module.sh`:
```bash
MODULE_NAME="new-module"
MODULE_DESCRIPTION="Description"
MODULE_REQUIRES=(...)
MODULE_PROVIDES=(...)

declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="..."
MODULE_PACKAGES[debian]="..."

module_install() { ... }
module_proofs() { ... }
```
