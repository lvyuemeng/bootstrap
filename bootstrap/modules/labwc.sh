#!/bin/bash
# =============================================================================
# Module: labwc
# =============================================================================
# labwc - Labwc window manager (wlroots-based)
# =============================================================================

MODULE_NAME="labwc"
MODULE_DESCRIPTION="Labwc Wayland window manager"

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
    "window:floating"
    "display:compositor"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# labwc packages
MODULE_PACKAGES[arch]="labwc"
MODULE_PACKAGES[debian]="labwc"
MODULE_PACKAGES[ubuntu]="labwc"
MODULE_PACKAGES[fedora]="labwc"
MODULE_PACKAGES[opensuse]="labwc"
MODULE_PACKAGES[alpine]="labwc"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check labwc binary
    echo "  [PROOF] Checking labwc..."
    proof_command "labwc" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "labwc")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/labwc/rc.xml" ]]; then
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
    
    # Setup labwc config
    setup_labwc_config
    
    # Setup XDG runtime dir
    setup_xdg_runtime
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP LABWC CONFIG
# =============================================================================

setup_labwc_config() {
    local config_dir="${HOME}/.config/labwc"
    
    # Find user's config
    local user_config
    user_config=$(config_find "labwc")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/rc.xml"
        fi
        echo "Using user's labwc config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/rc.xml" ]]; then
            cat > "${config_dir}/rc.xml" << 'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <gap>10</gap>
    <borderSize>2</borderSize>
    <autoRaise>no</autoRaise>
    <focusFollowMouse>yes</focusFollowMouse>
  </core>
  
  <theme>
    <name>Catppuccin-Mocha</name>
    <font place="ActiveWindow"><name>JetBrains Mono</name><size>11</size></font>
    <font place="MenuItem"><name>JetBrains Mono</name><size>11</size></font>
  </theme>
  
  <keybind key="A-F4">
    <action name="Close"/>
  </keybind>
  <keybind key="A-Tab">
    <action name="NextWindow"/>
  </keybind>
  <keybind key="A-S-Tab">
    <action name="PreviousWindow"/>
  </keybind>
  <keybind key="A-Space">
    <action name="Execute" command="wofi --show drun"/>
  </keybind>
  <keybind key="Print">
    <action name="Execute" command="grim -g \"$(slurp)\" - | wl-copy"/>
  </keybind>
  <keybind key="S-Print">
    <action name="Execute" command="grim - | wl-copy"/>
  </keybind>
</labwc_config>
EOF
            echo "Created default labwc config"
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
    
    if proof_command "labwc"; then
        echo "✓ labwc is installed"
    else
        echo "✗ labwc not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "labwc has been installed."
    echo ""
    echo "To start labwc:"
    echo "  labwc"
    echo ""
    echo "Key features:"
    echo "  - Openbox-like experience on Wayland"
    echo "  - wlroots-based"
    echo "  - XML configuration"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/labwc/rc.xml"
}
