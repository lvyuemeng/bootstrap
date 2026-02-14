#!/bin/bash
# =============================================================================
# Module: i3-wm
# =============================================================================
# i3 tiling window manager - lightweight, configurable tiling WM
# =============================================================================

MODULE_NAME="i3-wm"
MODULE_DESCRIPTION="i3 tiling window manager"

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
    "dbus"
)

MODULE_PROVIDES=(
    "window:manager"
    "window:tiling"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# i3 packages
MODULE_PACKAGES[arch]="i3-wm i3status i3lock dmenu"
MODULE_PACKAGES[debian]="i3 i3status i3lock dmenu"
MODULE_PACKAGES[ubuntu]="i3 i3status i3lock dmenu"
MODULE_PACKAGES[fedora]="i3 i3status i3lock dmenu"
MODULE_PACKAGES[opensuse]="i3 i3status i3lock dmenu"
MODULE_PACKAGES[alpine]="i3-wm i3status i3lock dmenu"
MODULE_PACKAGES[void]="i3 i3status i3lock dmenu"
MODULE_PACKAGES[gentoo]="x11-wm/i3 x11-misc/i3status x11-misc/i3lock x11-misc/dmenu"

# Optional: i3-gaps (more features)
declare -A MODULE_PACKAGES_GAPS
MODULE_PACKAGES_GAPS[arch]="i3-gaps"
MODULE_PACKAGES_GAPS[debian]="i3-wm"  # gaps in debian package

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check i3 binary
    echo "  [PROOF] Checking i3..."
    proof_command "i3" || result=1
    
    # Proof Level 2: Check i3-msg
    echo "  [PROOF] Checking i3-msg..."
    proof_command "i3-msg" || result=1
    
    # Proof Level 3: Check i3status
    echo "  [PROOF] Checking i3status..."
    proof_command "i3status" || result=1
    
    # Proof Level 4: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "i3")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/i3/config" ]]; then
        echo "  [PROOF] ✓ Config file exists"
    else
        echo "  [INFO] No config found - i3 will use defaults"
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
    
    # Setup i3 config
    setup_i3_config
    
    # Setup i3status config
    setup_i3status_config
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP I3 CONFIG
# =============================================================================

setup_i3_config() {
    local config_dir="${HOME}/.config/i3"
    local config_file="${config_dir}/config"
    
    # Find user's config
    local user_config
    user_config=$(config_find "i3")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        # User has config in dotfiles - link it
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "$config_file"
        fi
        echo "Using user's i3 config from dotfiles"
    else
        # No user config - i3 will use defaults
        echo "Note: i3 will use default config on first run"
        echo "Config location: $config_file"
    fi
}

# =============================================================================
# SETUP I3STATUS CONFIG
# =============================================================================

setup_i3status_config() {
    local config_dir="${HOME}/.config/i3status"
    local config_file="${config_dir}/config"
    
    # Find user's config
    local user_config
    user_config=$(config_find "i3status")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "$config_file"
        fi
        echo "Using user's i3status config"
    else
        echo "Note: i3status will use default config on first run"
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME installation..."
    
    # Run proofs
    module_proofs
    
    # Check i3 version
    echo ""
    echo "i3 version:"
    i3 --version 2>&1 || true
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

Starting i3:
  # From console (add to ~/.xinitrc):
  exec i3
  
  # Or use xinit/startx

Configuration:
  ~/.config/i3/config           # Main config

User Config Locations (auto-discovered):
  ~/.dotfiles/i3/              # git dotfiles
  ~/.config/i3/                # direct config
  ~/.config/chezmoi/home_i3    # chezmoi source

EOF
}
