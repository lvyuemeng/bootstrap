#!/bin/bash
# =============================================================================
# Module: niri
# =============================================================================
# niri - Scrollable-tiling Wayland compositor
# =============================================================================

MODULE_NAME="niri"
MODULE_DESCRIPTION="Scrollable-tiling Wayland compositor"

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
)

MODULE_PROVIDES=(
    "window:manager"
    "window:tiling"
    "display:compositor"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# niri - typically built from source or available in AUR
MODULE_PACKAGES[arch]="niri"  # AUR
MODULE_PACKAGES[debian]=""    # build from source
MODULE_PACKAGES[ubuntu]=""    # build from source
MODULE_PACKAGES[fedora]="niri"
MODULE_PACKAGES[opensuse]="niri"
MODULE_PACKAGES[alpine]=""     # build from source

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check niri binary
    echo "  [PROOF] Checking niri..."
    proof_command "niri" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "niri")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/niri/config.ron" ]]; then
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
        echo "Warning: niri not available as package for $distro"
        echo "Please build from source: https://github.com/YaLTeR/niri"
        echo "Or use cargo: cargo install niri"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Setup niri config
    setup_niri_config
    
    # Setup XDG runtime dir
    setup_xdg_runtime
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP NIRI CONFIG
# =============================================================================

setup_niri_config() {
    local config_dir="${HOME}/.config/niri"
    
    # Find user's config
    local user_config
    user_config=$(config_find "niri")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/config.ron"
        fi
        echo "Using user's niri config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/config.ron" ]]; then
            cat > "${config_dir}/config.ron" << 'EOF'
(
    // Niri configuration
    // https://github.com/YaLTeR/niri/wiki/Configuration
    
   /workspaces: (
        columns: 3,
        rows: 3,
    ),
    
    // Keybindings
    // See default keybindings: niri msg action print-keybinds
    // Override them:
    // keybind: [
    //     Mod4,
    //     "Q",
    //     "Close",
    // ],
)
EOF
            echo "Created default niri config"
        fi
    fi
}

# =============================================================================
# SETUP XDG RUNTIME DIR
# =============================================================================

setup_xdg_runtime() {
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
    
    if proof_command "niri"; then
        echo "✓ niri is installed"
    else
        echo "✗ niri not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "niri has been installed."
    echo ""
    echo "To start niri:"
    echo "  niri"
    echo ""
    echo "Key features:"
    echo "  - Scrollable tiling (windows can scroll within their tiles)"
    echo "  - MPRIS support"
    echo "  - Foreign Toplevel support"
    echo ""
    echo "Key commands:"
    echo "  niri msg action print-keybinds  # Show all keybinds"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/niri/config.ron"
}
