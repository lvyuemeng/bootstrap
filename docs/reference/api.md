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

## Config Discovery

```bash
config_find "module-name"
# Find user config in portable locations:
# - ~/.dotfiles/<module>/
# - ~/.config/<module>/
# - ~/.config/chezmoi/home_<module>
# - ~/.config/bootstrap/overrides/<module>

config_find_file "module" "filename"
# Find specific config file
```

## Autostart

```bash
autostart_add "command" [args...]
# Add application to autostart (~/.config/autostart/)

autostart_exists "command"
# Check if autostart entry exists

autostart_remove "command"
# Remove autostart entry
```

## Bootstrap Config

```bash
config_load
# Load ~/.config/bootstrap.conf

config_get_modules
# Get modules list from BOOTSTRAP_MODULES env var

config_init_dotfiles
# Initialize ~/.dotfiles directory

config_status
# Show config status
```

## Module Functions

Each module should define:

```bash
MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

MODULE_REQUIRES=("dep1" "dep2")
MODULE_PROVIDES=("service:daemon")

declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="package-name"
MODULE_PACKAGES[debian]="package-name"

module_install() { ... }
module_proofs() { ... }
module_verify() { ... }
module_info() { ... }
```

## Proof Functions

```bash
proof_command "cmd"        # Check command exists
proof_process "name"        # Check process running
proof_service_active "svc"  # Check systemd service
proof_dbus_service "name"   # Check D-Bus service
proof_kernel_module "mod"   # Check kernel module
proof_file "path"          # Check file exists
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
svc_status "service"       # Check service status
```
