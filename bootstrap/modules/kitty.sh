#!/bin/bash
# =============================================================================
# Module: kitty
# =============================================================================
# kitty - GPU-accelerated terminal emulator
# =============================================================================

MODULE_NAME="kitty"
MODULE_DESCRIPTION="GPU-accelerated terminal"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=()

MODULE_PROVIDES=(
    "desktop:terminal"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# kitty packages
MODULE_PACKAGES[arch]="kitty"
MODULE_PACKAGES[debian]="kitty"
MODULE_PACKAGES[ubuntu]="kitty"
MODULE_PACKAGES[fedora]="kitty"
MODULE_PACKAGES[opensuse]="kitty"
MODULE_PACKAGES[alpine]="kitty"
MODULE_PACKAGES[void]="kitty"
# gentoo: emerge -av kitty

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check kitty binary
    echo "  [PROOF] Checking kitty..."
    proof_command "kitty" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "kitty")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
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
    
    # Setup kitty config
    setup_kitty_config
    
    # Setup keyboard shortcuts for Wayland/X11
    setup_keyboard_shortcuts
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP KITTY CONFIG
# =============================================================================

setup_kitty_config() {
    local config_dir="${HOME}/.config/kitty"
    
    # Find user's config
    local user_config
    user_config=$(config_find "kitty")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/kitty.conf"
        fi
        echo "Using user's kitty config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/kitty.conf" ]]; then
            cat > "${config_dir}/kitty.conf" << 'EOF'
# Font
font_size 11.0
font_family JetBrains Mono

# Colors - Catppuccin Mocha
background #1e1e2e
foreground #cdd6f4
selection_background #89b4fa
selection_foreground #1e1e2e

# Cursor
cursor_shape block
cursor_blink_interval 0.5

# Scrollback
scrollback_lines 10000

# Window
window_padding_width 5
window_border_width 1pt

# Performance
repaint_delay 10
input_delay 3
sync_to_monitor yes
EOF
            echo "Created default kitty config"
        fi
        
        # Setup kitty shell integration
        echo "Installing kitty shell integration..."
        kitty +setupshell bash 2>/dev/null || true
    fi
}

# =============================================================================
# SETUP KEYBOARD SHORTCUTS
# =============================================================================

setup_keyboard_shortcuts() {
    # Create kitty.desktop for desktop integration
    local desktop_dir="${HOME}/.local/share/applications"
    mkdir -p "$desktop_dir"
    
    if [[ ! -f "${desktop_dir}/kitty.desktop" ]]; then
        cat > "${desktop_dir}/kitty.desktop" << 'EOF'
[Desktop Entry]
Name=kitty
Comment=GPU-accelerated terminal
Exec=kitty
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
Keywords=terminal;shell;command;
EOF
        echo "Created kitty.desktop"
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "kitty"; then
        echo "✓ kitty is installed"
    else
        echo "✗ kitty not found"
        return 1
    fi
    
    # Check version
    local version
    version=$(kitty --version 2>/dev/null | head -1)
    echo "  Version: $version"
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "kitty has been installed."
    echo ""
    echo "To start kitty:"
    echo "  kitty"
    echo ""
    echo "Key features:"
    echo "  - GPU rendering"
    echo "  - ligatures support"
    echo "  - remote control"
    echo "  - tabs and splits"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/kitty/kitty.conf"
}
