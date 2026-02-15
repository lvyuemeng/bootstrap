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

## Philosophy

| Principle | Description |
|-----------|-------------|
| **Flat Modules** | No folders, no categories - just modules |
| **Dependency-Driven** | Order determined by MODULE_REQUIRES |
| **Composable** | User selects modules, system resolves order |
| **Portable Config** | bootstrap.conf stored in user's dotfiles |

---

## Module Structure

### Flat Directory

```
modules/
├── dbus.sh
├── udev.sh
├── sway.sh
├── i3.sh
├── audio-pipewire.sh
├── bluetooth-stack.sh
├── network-manager.sh
└── ... (flat list)
```

**No subdirectories** - all modules in one directory.

### Module Contract

Each module must define:

```bash
MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

# Dependencies (required for this module to work)
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

---

## Core Libraries

### config.sh - Configuration Management

File system primitives for dotfiles integration:

```bash
config_link "source" "target"           # Symlink file
config_link_dir "source" "target"       # Symlink directory
config_ensure_dir "path"                # Ensure directory exists
```

### proof.sh - Verification Framework

Atomic verification primitives:

```bash
proof_process "bluetoothd"              # Check process running
proof_service_active "bluetooth"         # Check systemd service
proof_kernel_module "btusb"              # Check kernel module
proof_dbus_service "org.bluez"           # Check D-Bus service
proof_command "nmcli"                    # Check command available
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

### deps.sh - Dependency Resolution

Topological sort based on MODULE_REQUIRES.

```bash
deps_resolve "sway" "bluetooth-stack"
# Returns: dbus wlroots sway bluetooth-stack

deps_order "module1" "module2"
# Returns installation order
```

### state.sh - State Management

Track installed modules.

```bash
state_load     # Load from bootstrap.state.json
state_save     # Save current state
state_get "sway"  # Get module state
```

### core.sh - Module Orchestration

Module loading and installation.

```bash
load_module "module-name"           # Load module
install_module "module-name"        # Install with verification
bootstrap "config-file"            # Run bootstrap workflow
```

### log.sh - Logging System

Structured logging with levels and file output.

```bash
log_info "Installing module"        # Normal operation messages
log_warn "Package not found"       # Non-fatal warnings
log_error "Installation failed"     # Fatal errors
log_debug "Debug info"              # Verbose debugging (requires VERBOSE=1)

log_success "Task completed"        # Success with checkmark
log_fail "Task failed"             # Failure with X mark
log_section "Section Title"         # Section header
```

---

## Bootstrap Config

User creates `bootstrap.conf` in their dotfiles:

```bash
# bootstrap.conf
BOOTSTRAP_MODULES=(
    "sway"
    "bluetooth-stack"
    "audio-pipewire"
    "network-manager"
)

# Optional overrides
OVERRIDES=(
    "~/.config/sway/config"
)
```

Store anywhere: git, home-manager, chezmoi, etc.

---

## Bootstrap CLI

```bash
# Install all modules from bootstrap.conf
./bootstrap.sh install

# Install specific module (auto-resolves deps)
./bootstrap.sh install sway

# Verify installation
./bootstrap.sh verify [module]

# Run proof checks
./bootstrap.sh proof <module>

# Show status
./bootstrap.sh status

# Reset state
./bootstrap.sh reset
```

---

## Data Flow

```
User writes bootstrap.conf
         │
         ▼
bootstrap.sh reads config
         │
         ▼
deps.sh resolves dependencies
(topological sort)
         │
         ▼
core.sh loads modules
         │
         ├─► distro.sh (detect system)
         ├─► config.sh (link configs)
         ├─► proof.sh (verify)
         └─► Install packages → Start services
```

---

## Logging Configuration

### Log Levels

| Level | Function | Description |
|-------|----------|-------------|
| DEBUG | `log_debug` | Verbose debugging (requires `VERBOSE=1`) |
| INFO | `log_info` | Normal operation messages (default) |
| WARN | `log_warn` | Warnings (non-fatal issues) |
| ERROR | `log_error` | Errors (fatal issues) |

### Environment Variables

- `VERBOSE=1` - Enable debug logging
- `LOG_FILE=/path/to/log` - Custom log file location
- `LOG_LEVEL=warn` - Set minimum log level (debug, info, warn, error)

### Log Files

- Console: stdout with colored output (when terminal supports it)
- File: `${BOOTSTRAP_DIR}/logs/bootstrap.log`
- Rotation: Auto-rotate at 10MB, keep last 5 rotated logs

### Usage in Modules

```bash
# Use logging functions instead of echo
module_install() {
    log_info "Installing my module"
    
    if ! some_command; then
        log_error "Command failed"
        return 1
    fi
    
    log_success "Module installed"
}
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
