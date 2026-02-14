#!/bin/bash
# =============================================================================
# Module: openbox
# =============================================================================
# Openbox - lightweight, highly configurable window manager
# =============================================================================

MODULE_NAME="openbox"
MODULE_DESCRIPTION="Openbox window manager"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "x11-server"
)

MODULE_PROVIDES=(
    "window:manager"
    "window:floating"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Openbox packages
MODULE_PACKAGES[arch]="openbox obconf obmenu menu"
MODULE_PACKAGES[debian]="openbox obconf obmenu menu"
MODULE_PACKAGES[ubuntu]="openbox obconf"
MODULE_PACKAGES[fedora]="openbox obconf"
MODULE_PACKAGES[opensuse]="openbox"
MODULE_PACKAGES[alpine]="openbox"
MODULE_PACKAGES[void]="openbox"
MODULE_PACKAGES[gentoo]="x11-wm/openbox x11-misc/obconf x11-misc/menu"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check openbox binary
    echo "  [PROOF] Checking openbox..."
    proof_command "openbox" || result=1
    
    # Proof Level 2: Check obconf
    echo "  [PROOF] Checking obconf..."
    proof_command "obconf" || result=1
    
    # Proof Level 3: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "openbox")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/openbox/rc.xml" ]]; then
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
    
    # Setup openbox config
    setup_openbox_config
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP OPENBOX CONFIG
# =============================================================================

setup_openbox_config() {
    local config_dir="${HOME}/.config/openbox"
    
    # Find user's config
    local user_config
    user_config=$(config_find "openbox")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        # User has config in dotfiles - link it
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            # Single file
            config_link "$user_config" "${config_dir}/rc.xml"
        fi
        echo "Using user's openbox config from dotfiles"
    else
        # Generate default config if not exists
        if [[ ! -f "${config_dir}/rc.xml" ]]; then
            echo "Generating default openbox config..."
            mkdir -p "$config_dir"
            # openbox --copy-default-config would work but requires X
            echo "Note: Run 'openbox --reconfigure' after first login to generate config"
        fi
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    # Check openbox binary
    if proof_command "openbox"; then
        echo "✓ openbox is installed"
    else
        echo "✗ openbox not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "Openbox has been installed."
    echo ""
    echo "To start openbox:"
    echo "  echo 'exec openbox' > ~/.xinitrc"
    echo "  startx"
    echo ""
    echo "Key commands:"
    echo "  openbox --reconfigure   # Reload config"
    echo "  obconf                  # Configuration tool"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/openbox/rc.xml"
}
