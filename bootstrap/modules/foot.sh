#!/bin/bash
# =============================================================================
# Module: foot
# =============================================================================
# foot - Fast, lightweight Wayland terminal emulator
# =============================================================================

MODULE_NAME="foot"
MODULE_DESCRIPTION="Wayland terminal emulator"

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
    "desktop:terminal"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# foot packages
MODULE_PACKAGES[arch]="foot"
MODULE_PACKAGES[debian]="foot"
MODULE_PACKAGES[ubuntu]="foot"
MODULE_PACKAGES[fedora]="foot"
MODULE_PACKAGES[opensuse]="foot"
MODULE_PACKAGES[alpine]="foot"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check foot binary
    echo "  [PROOF] Checking foot..."
    proof_command "foot" || result=1
    
    # Proof Level 2: Check footserver
    echo "  [PROOF] Checking footserver..."
    proof_command "footserver" || result=1
    
    # Proof Level 3: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "foot")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/foot/foot.ini" ]]; then
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
    
    # Setup foot config
    setup_foot_config
    
    # Setup footserver autostart
    setup_footserver
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP FOOT CONFIG
# =============================================================================

setup_foot_config() {
    local config_dir="${HOME}/.config/foot"
    
    # Find user's config
    local user_config
    user_config=$(config_find "foot")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/foot.ini"
        fi
        echo "Using user's foot config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/foot.ini" ]]; then
            cat > "${config_dir}/foot.ini" << 'EOF'
[main]
font=JetBrains Mono:size=11
pad=5x5

[colors]
background=1e1e2e
foreground=cdd6f4
selection-background=89b4fa
selection-foreground=1e1e2e

# Catppuccin Mocha colors
black=45475a
red=f38ba8
green=a6e3a1
yellow=f9e2af
blue=89b4fa
magenta=cba6f7
cyan=94e2d5
white=bac2de
bright-black=585b70
bright-red=f38ba8
bright-green=a6e3a1
bright-yellow=f9e2af
bright-blue=89b4fa
bright-magenta=cba6f7
bright-cyan=94e2d5
white=cdd6f4

[cursor]
style=block
blink=yes

[scrollback]
lines=10000

[keybindings]
copy=Control+Shift+C
paste=Control+Shift+V
spawn-terminal=Control+Shift+N
EOF
            echo "Created default foot config"
        fi
    fi
}

# =============================================================================
# SETUP FOOTSERVER
# =============================================================================

setup_footserver() {
    # footserver is needed for foot to work properly
    # Add to autostart if using Wayland
    autostart_add "footserver" 2>/dev/null || true
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "foot"; then
        echo "✓ foot is installed"
    else
        echo "✗ foot not found"
        return 1
    fi
    
    # Check version
    local version
    version=$(foot --version 2>/dev/null)
    echo "  Version: $version"
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "foot has been installed."
    echo ""
    echo "To start foot:"
    echo "  foot"
    echo ""
    echo "Note: footserver runs automatically for better performance"
    echo ""
    echo "Key features:"
    echo "  - Minimal resource usage"
    echo "  - True color support"
    echo "  - ligatures support"
    echo "  - Multiple cursor styles"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/foot/foot.ini"
}
