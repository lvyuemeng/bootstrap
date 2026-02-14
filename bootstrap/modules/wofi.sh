#!/bin/bash
# =============================================================================
# Module: wofi
# =============================================================================
# wofi - Launcher for Wayland (dmenu replacement)
# =============================================================================

MODULE_NAME="wofi"
MODULE_DESCRIPTION="Wayland application launcher"

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
    "desktop:launcher"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# wofi packages
MODULE_PACKAGES[arch]="wofi"
MODULE_PACKAGES[debian]="wofi"
MODULE_PACKAGES[ubuntu]="wofi"
MODULE_PACKAGES[fedora]="wofi"
MODULE_PACKAGES[opensuse]="wofi"
MODULE_PACKAGES[alpine]="wofi"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check wofi binary
    echo "  [PROOF] Checking wofi..."
    proof_command "wofi" || result=1
    
    # Proof Level 2: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "wofi")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/wofi/config" ]]; then
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
    
    # Setup wofi config
    setup_wofi_config
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP WOFI CONFIG
# =============================================================================

setup_wofi_config() {
    local config_dir="${HOME}/.config/wofi"
    
    # Find user's config
    local user_config
    user_config=$(config_find "wofi")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/config"
        fi
        echo "Using user's wofi config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/config" ]]; then
            cat > "${config_dir}/config" << 'EOF'
width=600
height=400
location=center
show=drun
prompt=Search...
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=32
EOF
            echo "Created default wofi config"
        fi
        
        # Create default style
        if [[ ! -f "${config_dir}/style.css" ]]; then
            cat > "${config_dir}/style.css" << 'EOF'
window {
    background-color: #1e1e2e;
    border: 2px solid #89b4fa;
    border-radius: 8px;
}

#input {
    background-color: #313244;
    color: #cdd6f4;
    border: none;
    border-bottom: 2px solid #89b4fa;
    padding: 10px;
    margin: 5px;
    border-radius: 4px;
}

#entry:selected {
    background-color: #89b4fa;
    color: #1e1e2e;
}

#text {
    color: #cdd6f4;
}

#image {
    margin-right: 10px;
}
EOF
            echo "Created default wofi style"
        fi
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "wofi"; then
        echo "✓ wofi is installed"
    else
        echo "✗ wofi not found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "wofi has been installed."
    echo ""
    echo "Key commands:"
    echo "  wofi              # Show app launcher"
    echo "  wofi --show run  # Show run dialog"
    echo "  wofi --show window  # Show window switcher"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/wofi/config"
    echo "  ~/.config/wofi/style.css"
}
