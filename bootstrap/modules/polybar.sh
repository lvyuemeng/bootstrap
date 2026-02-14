#!/bin/bash
# =============================================================================
# Module: polybar
# =============================================================================
# Polybar - fast and easy-to-use status bar
# =============================================================================

MODULE_NAME="polybar"
MODULE_DESCRIPTION="Fast and extensible status bar"

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
    "panel:statusbar"
    "panel:workspace"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Polybar packages
MODULE_PACKAGES[arch]="polybar"
MODULE_PACKAGES[debian]="polybar"
MODULE_PACKAGES[ubuntu]="polybar"
MODULE_PACKAGES[fedora]="polybar"
MODULE_PACKAGES[opensuse]="polybar"
MODULE_PACKAGES[alpine]="polybar"
MODULE_PACKAGES[void]="polybar"
MODULE_PACKAGES[gentoo]="x11-misc/polybar"

# Dependencies (if needed separately)
declare -A MODULE_PACKAGES_DEPS
MODULE_PACKAGES_DEPS[debian]="libuv1-dev libxcb1-dev libxcb-util0-dev libxcb-randr0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev python3-xcbgen"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check polybar binary
    echo "  [PROOF] Checking polybar..."
    proof_command "polybar" || result=1
    
    # Proof Level 2: Check polybar msg (IPC)
    echo "  [PROOF] Checking polybar-msg..."
    proof_command "polybar-msg" || result=1
    
    # Proof Level 3: Check xrandr (for monitors)
    echo "  [PROOF] Checking xrandr..."
    proof_command "xrandr" || result=1
    
    # Proof Level 4: Check config file (from user's dotfiles or default)
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "polybar")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/polybar/config.ini" ]]; then
        echo "  [PROOF] ✓ Config file exists"
    else
        echo "  [INFO] No config found - polybar will create default on first run"
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
    pkg_install "$packages" "$distro"
    
    # Setup polybar config (from user's dotfiles or widget default)
    setup_polybar_config
    
    # Setup launch script
    setup_polybar_launch
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP POLYBAR CONFIG
# =============================================================================

setup_polybar_config() {
    local config_dir="${HOME}/.config/polybar"
    
    # Find user's config in portable locations
    local user_config
    user_config=$(config_find "polybar")
    
    if [[ -n "$user_config" ]]; then
        # User has config in their dotfiles - link it
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_ensure_dir "$config_dir"
            config_link "$user_config" "$config_dir/config.ini"
        fi
        echo "Using user's polybar config from dotfiles"
    else
        # No user config - polybar will create default on first run
        echo "Note: polybar will create default config on first run"
        echo "Config location: $config_dir/config.ini"
    fi
}

# =============================================================================
# SETUP POLYBAR LAUNCH
# =============================================================================

setup_polybar_launch() {
    local bin_dir="${HOME}/.local/bin"
    local launch_script="${bin_dir}/polybar-launch"
    
    # Check if user has custom launch script
    local user_script
    user_script=$(config_find_file "polybar" "polybar-launch")
    
    config_ensure_dir "$bin_dir"
    
    if [[ -n "$user_script" ]]; then
        # Link user's launch script
        config_link "$user_script" "$launch_script"
    else
        # Create default launch script if not exists
        if [[ ! -f "$launch_script" ]]; then
            cat > "$launch_script" <<'EOF'
#!/bin/bash
# Polybar launch script

killall polybar 2>/dev/null

# Get monitors
MONITORS=$(xrandr --query | grep " connected" | cut -d" " -f1)

for m in $MONITORS; do
    MONITOR=$m polybar main &
done

echo "Polybar started"
EOF
            chmod +x "$launch_script"
            echo "Created default polybar-launch script"
        fi
    fi
    
    # Add to i3 config if exists
    local i3_config="${HOME}/.config/i3/config"
    if [[ -f "$i3_config" ]]; then
        if ! grep -q "polybar-launch" "$i3_config" 2>/dev/null; then
            echo "" >> "$i3_config"
            echo "# Polybar" >> "$i3_config"
            echo "exec_always --no-startup-id ~/.local/bin/polybar-launch" >> "$i3_config"
            echo "Added polybar to i3 config"
        fi
    fi
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME installation..."
    
    local distro
    distro=$(distro_detect)
    local init
    init=$(init_detect)
    
    echo "Running on: distro=$distro, init=$init"
    
    # Run proofs
    module_proofs
    
    # Check polybar version
    echo ""
    echo "Polybar version:"
    polybar --version 2>&1 || true
    
    # List monitors
    echo ""
    echo "Available monitors:"
    xrandr --query 2>&1 | grep " connected" || true
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

Starting Polybar:
  ~/.local/bin/polybar-launch
  
  # Or manually:
  MONITOR=HDMI-1 polybar main

Configuration:
  ~/.config/polybar/config.ini    # Main config

User Config Locations (auto-discovered):
  ~/.dotfiles/polybar/           # git dotfiles
  ~/.config/polybar/             # direct config
  ~/.config/chezmoi/home_polybar # chezmoi source

Troubleshooting:
  # No icons showing
  Install: Font Awesome 6
  
  # Modules not working
  Check: polybar -l info

EOF
}
