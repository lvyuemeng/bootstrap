#!/bin/bash
# =============================================================================
# Module: river
# =============================================================================
# river - Dynamic tiling Wayland compositor
# =============================================================================

MODULE_NAME="river"
MODULE_DESCRIPTION="Dynamic tiling Wayland compositor"

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
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# river packages
MODULE_PACKAGES[arch]="river"
MODULE_PACKAGES[debian]="river"
MODULE_PACKAGES[ubuntu]="river"
MODULE_PACKAGES[fedora]="river"
MODULE_PACKAGES[opensuse]="river"
MODULE_PACKAGES[alpine]="river"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check river binary
    echo "  [PROOF] Checking river..."
    proof_command "river" || result=1
    
    # Proof Level 2: Check rivertctl
    echo "  [PROOF] Checking riverctl..."
    proof_command "riverctl" || result=1
    
    # Proof Level 3: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "river")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/river/init" ]]; then
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
    
    # Setup river config
    setup_river_config
    
    # Setup XDG runtime dir
    setup_xdg_runtime
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP RIVER CONFIG
# =============================================================================

setup_river_config() {
    local config_dir="${HOME}/.config/river"
    
    # Find user's config
    local user_config
    user_config=$(config_find "river")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/init"
        fi
        echo "Using user's river config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/init" ]]; then
            cat > "${config_dir}/init" << 'EOF'
#!/bin/bash
# River initialization script

# Layout
riverctl default-layout rivertile

# Mod key
riverctl map-pointer Normal Mod4 button-off on
riverctl map-pointer Normal Mod4 button-resize-on resize

# Scratchpad
riverctl map Normal Mod4 P toggle-focused-tags 31
riverctl map Normal Mod4 S spawn-scratchpad

# Tags
for i in $(seq 1 9); do
    riverctl map Normal Mod4 $i set-focused-tags $((1 << ($i - 1)))
    riverctl map Normal Mod4 Shift $i set-view-tags $((1 << ($i - 1)))
done

# Float
riverctl map Normal Mod4 F toggle-float
riverctl map Normal Mod4 Space zoom

# Close
riverctl map Normal Mod4 Q close

# Reload
riverctl map Normal Mod4 R spawn "riverctl reload"

# Programs
riverctl map Normal Mod4 Return spawn "alacritty"
riverctl map Normal Mod4 D wofi --show drun

# Media keys
riverctl map Normal None Print spawn "grim -g \"$(slurp)\" - | wl-copy"
riverctl map Normal Shift Print spawn "grim - | wl-copy"

# Input
riverctl input "virtual:Libinput_Touchpad" tap enabled
riverctl input "virtual:Libinput_Touchpad" disable-while-typing enabled
EOF
            echo "Created default river config"
            chmod +x "${config_dir}/init"
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
    
    if proof_command "river"; then
        echo "✓ river is installed"
    else
        echo "✗ river not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "river has been installed."
    echo ""
    echo "To start river:"
    echo "  river"
    echo ""
    echo "Key features:"
    echo "  - Dynamic tiling"
    echo "  - Tags (workspaces)"
    echo "  - Scratchpad"
    echo ""
    echo "Key commands:"
    echo "  riverctl            # Control river"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/river/init"
}
