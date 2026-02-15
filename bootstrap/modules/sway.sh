#!/bin/bash
# =============================================================================
# Module: sway
# =============================================================================
# sway - i3-compatible Wayland compositor
# =============================================================================

MODULE_NAME="sway"
MODULE_DESCRIPTION="i3-compatible Wayland compositor"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "wayland"
    "dbus"
    "wlroots"
)

MODULE_PROVIDES=(
    "window:manager"
    "window:tiling"
    "display:compositor"
)

# =============================================================================
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

# sway packages - keyed by package manager
MODULE_PACKAGES[pacman]="sway swayidle swaylock grim slurp"
MODULE_PACKAGES[apt]="sway swayidle swaylock grim slurp"
MODULE_PACKAGES[dnf]="sway swayidle swaylock grim slurp"
MODULE_PACKAGES[zypper]="sway swayidle swaylock grim slurp"
MODULE_PACKAGES[apk]="sway swayidle swaylock grim slurp"
MODULE_PACKAGES[xbps]="sway"
MODULE_PACKAGES[emerge]="x11-wm/sway x11-misc/swayidle x11-misc/swaylock media-gfx/grim x11-misc/slurp"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check sway binary
    echo "  [PROOF] Checking sway..."
    proof_command "sway" || result=1
    
    # Proof Level 2: Check swaymsg
    echo "  [PROOF] Checking swaymsg..."
    proof_command "swaymsg" || result=1
    
    # Proof Level 3: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "sway")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/sway/config" ]]; then
        echo "  [PROOF] ✓ Config file exists"
    else
        echo "  [INFO] No config found - will generate from i3 or defaults"
    fi
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    local init
    init=$(init_detect)
    
    echo "Detected: pkgmgr=$pkgmgr, init=$init"
    
    # Get packages for this pkgmgr
    local packages="${MODULE_PACKAGES[$pkgmgr]}"
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for pkgmgr: $pkgmgr"
        echo "Supported pkgmgrs: ${!MODULE_PACKAGES[*]}"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages" "$pkgmgr"
    
    # Setup sway config
    setup_sway_config
    
    # Setup XDG runtime dir
    setup_xdg_runtime
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP SWAY CONFIG
# =============================================================================

setup_sway_config() {
    local config_dir="${HOME}/.config/sway"
    
    # Find user's config
    local user_config
    user_config=$(config_find "sway")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/config"
        fi
        echo "Using user's sway config from dotfiles"
    else
        # Check for i3 config to migrate
        local i3_config
        i3_config=$(config_find "i3")
        
        if [[ -n "$i3_config" ]] || [[ -f "$HOME/.config/i3/config" ]]; then
            echo "Found i3 config - can migrate to sway"
            echo "Run: swaymsg -f /run/user/$(id -u)/sway-ipc.sock show config > ~/.config/sway/config"
        fi
        
        # Create minimal default config
        if [[ ! -f "${config_dir}/config" ]]; then
            cat > "${config_dir}/config" << 'EOF'
# Default sway config
# You can obtain a full config from i3 config with: swaymsg -f /run/user/$(id -u)/sway-ipc.sock show config > ~/.config/sway/config

# Exec on startup
exec waybar
exec mako

# Input configuration
input * {
    xkb_layout us
}

# Output configuration
output * bg #1e1e2e solid_color

# Window rules
for_window [class="^.*"] border pixel 2
for_window [floating] border pixel 2

# Key bindings
set $mod Mod4
floating_modifier $mod

# Kill focused window
bindsym $mod+Shift+q kill

# Reload config
bindsym $mod+Shift+r reload

# Exit sway
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -b 'Yes, exit sway' 'swaymsg exit'
EOF
            echo "Created default sway config"
        fi
    fi
}

# =============================================================================
# SETUP XDG RUNTIME DIR
# =============================================================================

setup_xdg_runtime() {
    # Ensure XDG_RUNTIME_DIR is set
    if [[ -z "$XDG_RUNTIME_DIR" ]]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
        echo "Created XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "sway"; then
        echo "✓ sway is installed"
    else
        echo "✗ sway not found"
        return 1
    fi
    
    # Check version
    local version
    version=$(sway --version 2>/dev/null | head -1)
    echo "  Version: $version"
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "sway has been installed."
    echo ""
    echo "To start sway:"
    echo "  sway"
    echo ""
    echo "Key commands:"
    echo "  swaymsg              # Control sway"
    echo "  swaylock             # Lock screen"
    echo "  swayidle             # Idle management"
    echo "  grim                 # Screenshot"
    echo "  slurp                # Select region"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/sway/config"
    echo ""
    echo "Tip: Migrate i3 config with:"
    echo "  swaymsg -f \$(ls -t /run/user/*/sway-ipc.* 2>/dev/null | head -1) show config > ~/.config/sway/config"
}
