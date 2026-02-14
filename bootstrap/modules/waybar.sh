#!/bin/bash
# =============================================================================
# Module: waybar
# =============================================================================
# waybar - Highly customizable Wayland bar
# =============================================================================

MODULE_NAME="waybar"
MODULE_DESCRIPTION="Wayland status bar"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "wayland-compositor"
)

MODULE_PROVIDES=(
    "desktop:panel"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# waybar packages
MODULE_PACKAGES[arch]="waybar"
MODULE_PACKAGES[debian]="waybar"
MODULE_PACKAGES[ubuntu]="waybar"
MODULE_PACKAGES[fedora]="waybar"
MODULE_PACKAGES[opensuse]="waybar"
MODULE_PACKAGES[alpine]="waybar"
# void and gentoo use build from source

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check waybar binary
    echo "  [PROOF] Checking waybar..."
    proof_command "waybar" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "waybar")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/waybar/config" ]]; then
        echo "  [PROOF] ✓ Config file exists"
    else
        echo "  [INFO] No config found - will use defaults"
    fi
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local distro
    distro=$(distro_detect)
    local init
    init=$(init_detect)
    
    echo "Detected: distro=$distro, init=$init"
    
    # Get packages for this distro
    local packages="${MODULE_PACKAGES[$distro]}"
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for distro: $distro"
        echo "Supported distros: ${!MODULE_PACKAGES[*]}"
        echo "Note: waybar may need to be built from source on this distro"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Setup waybar config
    setup_waybar_config
    
    # Setup autostart
    setup_autostart
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP WAYBAR CONFIG
# =============================================================================

setup_waybar_config() {
    local config_dir="${HOME}/.config/waybar"
    
    # Find user's config
    local user_config
    user_config=$(config_find "waybar")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        # User has config in dotfiles - link it
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/config"
        fi
        echo "Using user's waybar config from dotfiles"
    else
        # Create minimal default config
        if [[ ! -f "${config_dir}/config" ]]; then
            cat > "${config_dir}/config" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "battery", "tray"]
}
EOF
            echo "Created default waybar config"
        fi
        
        # Create default style
        if [[ ! -f "${config_dir}/style.css" ]]; then
            cat > "${config_dir}/style.css" << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono", monospace;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: #1e1e2e;
    color: #cdd6f4;
}

#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: #cdd6f4;
}

#workspaces button.active {
    background: #89b4fa;
    color: #1e1e2e;
}

#clock, #battery, #network, #pulseaudio {
    padding: 0 10px;
    margin: 0 4px;
}
EOF
            echo "Created default waybar style"
        fi
    fi
}

# =============================================================================
# SETUP AUTOSTART
# =============================================================================

setup_autostart() {
    autostart_add "waybar" 2>/dev/null || true
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "waybar"; then
        echo "✓ waybar is installed"
    else
        echo "✗ waybar not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "waybar has been installed."
    echo ""
    echo "To start waybar:"
    echo "  waybar"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/waybar/config"
    echo "  ~/.config/waybar/style.css"
}
