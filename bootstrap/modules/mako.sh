#!/bin/bash
# =============================================================================
# Module: mako
# =============================================================================
# mako - Lightweight notification daemon for Wayland
# =============================================================================

MODULE_NAME="mako"
MODULE_DESCRIPTION="Wayland notification daemon"

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
    "desktop:notification"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# mako packages
MODULE_PACKAGES[arch]="mako"
MODULE_PACKAGES[debian]="mako"
MODULE_PACKAGES[ubuntu]="mako"
MODULE_PACKAGES[fedora]="mako"
MODULE_PACKAGES[opensuse]="mako"
MODULE_PACKAGES[alpine]="mako"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check mako binary
    echo "  [PROOF] Checking mako..."
    proof_command "mako" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "mako")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/mako/config" ]]; then
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
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Setup mako config
    setup_mako_config
    
    # Setup autostart
    setup_autostart
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP MAKO CONFIG
# =============================================================================

setup_mako_config() {
    local config_dir="${HOME}/.config/mako"
    
    # Find user's config
    local user_config
    user_config=$(config_find "mako")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/config"
        fi
        echo "Using user's mako config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/config" ]]; then
            cat > "${config_dir}/config" << 'EOF'
max-visible=5
sort=-time
default-timeout=5000

style=font=JetBrains Mono 11
background-color=#1e1e2eee
text-color=#cdd6f4
border-color=#89b4fa
border-size=2
border-radius=8
padding=15
margin=10

[urgency=low]
border-color=#313244

[urgency=normal]
border-color=#89b4fa

[urgency=high]
border-color=#f38ba8
EOF
            echo "Created default mako config"
        fi
    fi
}

# =============================================================================
# SETUP AUTOSTART
# =============================================================================

setup_autostart() {
    autostart_add "mako" 2>/dev/null || true
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "mako"; then
        echo "✓ mako is installed"
    else
        echo "✗ mako not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "mako has been installed."
    echo ""
    echo "To start mako:"
    echo "  mako"
    echo ""
    echo "Key commands:"
    echo "  makoctl dismiss        # Dismiss notifications"
    echo "  makoctl clear         # Clear all"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/mako/config"
}
