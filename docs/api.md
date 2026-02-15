# Bootstrap API Reference

## File Operations

### Linking

```bash
config_link "source" "target"
# Create symlink: source → target
# Handles existing files by backing them up

config_link_dir "source_dir" "target_dir"
# Symlink entire directory
```

### Copying

```bash
config_copy "source" "target"
# Copy file: source → target

config_copy_dir "source_dir" "target_dir"
# Copy directory
```

### Utilities

```bash
config_backup "file" [backup_dir]
# Backup file to ~/.dotfiles/backups/

config_exists "path"
# Check if file/directory exists

config_is_link "path"
# Check if path is a symlink

config_is_dir "path"
# Check if path is a directory

config_ensure_dir "path"
# Ensure directory exists (create if not)
```

## Bootstrap Config

```bash
config_load
# Load bootstrap.conf from:
#   - ~/.config/bootstrap.conf
#   - ~/.config/bootstrap/bootstrap.conf
#   - ~/.config/bootstrap.yaml

config_status
# Show config status
```

## Module Functions

Each module should define:

```bash
MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

MODULE_REQUIRES=("dep1" "dep2")
MODULE_OPTIONAL=("opt-dep1")

MODULE_PROVIDES=("service:daemon")

declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="package-name"
MODULE_PACKAGES[debian]="package-name"

module_install() { ... }
module_proofs() { ... }
module_verify() { ... }
```

## Dependency Functions

```bash
deps_resolve "module1" "module2" ...
# Resolve dependencies and return ordered list
# Uses MODULE_REQUIRES from each module

deps_order "module1" "module2" ...
# Return installation order (topological sort)

deps_satisfied "module" "module1" "module2"
# Check if dependency is satisfied in the given list
```

## State Functions

```bash
state_load
# Load state from ~/.config/bootstrap/state.json

state_save
# Save current state

state_get "module"
# Get state for specific module

state_set "module" "installed"
# Set module state
```

## Proof Functions

```bash
proof_command "cmd"        # Check command exists
proof_process "name"        # Check process running
proof_service_active "svc"  # Check systemd service
proof_service_enabled "svc" # Check service is enabled
proof_dbus_service "name"   # Check D-Bus service
proof_kernel_module "mod"   # Check kernel module
proof_file "path"          # Check file exists
proof_user "name"          # Check user exists
proof_network_interface "iface" # Check network interface
```

## Distro Functions

```bash
distro=$(distro_detect)    # Detect: arch, debian, fedora, etc.
init=$(init_detect)        # Detect: systemd, openrc, runit

pkg_install "packages"      # Install packages
pkg_remove "packages"       # Remove packages

svc_enable "service"        # Enable service
svc_start "service"        # Start service
svc_stop "service"         # Stop service
svc_restart "service"      # Restart service
svc_status "service"       # Check service status
```
