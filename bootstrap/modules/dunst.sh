#!/bin/bash
# =============================================================================
# Module: notification-dunst
# =============================================================================
# Desktop notification daemon
# =============================================================================

MODULE_NAME="notification-dunst"
MODULE_DESCRIPTION="Dunst notification daemon"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"

# === REQUIREMENTS ===
MODULE_REQUIRES=(
    "dbus"
    "x11-server"
)

# === PROVIDES ===
MODULE_PROVIDES=(
    "notifications:daemon"
)

# === PROOFS ===
module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Check D-Bus
    echo "  [PROOF] Checking D-Bus..."
    proof_dbus_service "org.freedesktop.Notifications" || result=1
    
    # Check X11
    echo "  [PROOF] Checking X11..."
    if [[ -n "$DISPLAY" ]]; then
        echo "  [PROOF] DISPLAY=$DISPLAY"
    fi
    
    # Check dunst binary
    echo "  [PROOF] Checking dunst..."
    proof_command "dunst" || result=1
    
    return $result
}

# === INSTALL ===
module_install() {
    echo "Installing $MODULE_NAME..."
    
    # Install package (distro-specific)
    pkg_install "dunst"
    
    # Setup dunst config
    setup_dunst_config
    
    # Add to autostart
    autostart_add "dunst"
    
    echo "$MODULE_NAME installed"
}

# === SETUP CONFIG ===
setup_dunst_config() {
    local config_dir="${HOME}/.config/dunst"
    local config_file="${config_dir}/dunstrc"
    
    # Find user's config
    local user_config
    user_config=$(config_find "dunst")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "$config_file"
        fi
        echo "Using user's dunst config from dotfiles"
    else
        # No user config - dunst will create default on first run
        echo "Note: dunst will create default config on first run"
        echo "Config location: $config_file"
    fi
}

# === VERIFY ===
module_verify() {
    echo "Verifying $MODULE_NAME..."
    module_proofs
    
    # Test notification
    if command -v notify-send >/dev/null 2>&1; then
        echo "  Testing notification..."
        notify-send "$MODULE_NAME" "Test" 2>/dev/null || {
            echo "  Warning: notify-send failed"
        }
    fi
    
    return 0
}

# === INFO ===
module_info() {
    cat <<EOF

$MODULE_NAME installed!

Config: ${HOME}/.config/dunst/dunstrc

User Config Locations (auto-discovered):
  ~/.dotfiles/dunst/           # git dotfiles
  ~/.config/dunst/             # direct config
  ~/.config/chezmoi/home_dunstrc # chezmoi source

Usage:
  dunst              # Start daemon
  dunstctl           # Control

EOF
}
