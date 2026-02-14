#!/bin/bash
# =============================================================================
# Module: hyprland
# =============================================================================
# hyprland - Dynamic tiling Wayland compositor
# =============================================================================

MODULE_NAME="hyprland"
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

# hyprland packages - note: may need to be built from source on some distros
MODULE_PACKAGES[arch]="hyprland"
MODULE_PACKAGES[debian]="hyprland"
MODULE_PACKAGES[ubuntu]="hyprland"
MODULE_PACKAGES[fedora]="hyprland"
MODULE_PACKAGES[opensuse]="hyprland"
MODULE_PACKAGES[alpine]="hyprland"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check hyprland binary
    echo "  [PROOF] Checking hyprland..."
    proof_command "Hyprland" || proof_command "hyprland" || result=1
    
    # Proof Level 2: Check hyprctl
    echo "  [PROOF] Checking hyprctl..."
    proof_command "hyprctl" || result=1
    
    # Proof Level 3: Check config
    echo "  [PROOF] Checking config..."
    local user_config
    user_config=$(config_find "hypr")
    if [[ -n "$user_config" ]]; then
        echo "  [PROOF] ✓ User config found: $user_config"
    elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
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
        echo "Note: hyprland may need to be built from source on this distro"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Setup hyprland config
    setup_hyprland_config
    
    # Setup XDG runtime dir
    setup_xdg_runtime
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP HYPRLAND CONFIG
# =============================================================================

setup_hyprland_config() {
    local config_dir="${HOME}/.config/hypr"
    
    # Find user's config
    local user_config
    user_config=$(config_find "hypr")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/hyprland.conf"
        fi
        echo "Using user's hyprland config from dotfiles"
    else
        # Create default config
        if [[ ! -f "${config_dir}/hyprland.conf" ]]; then
            cat > "${config_dir}/hyprland.conf" << 'EOF'
# Hyprland configuration

# Monitor
monitor=,preferred,auto,1

# Input
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =
    
    follow_mouse = 1
    
    touchpad {
        natural_scroll = true
    }
}

# General
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faee)
    col.inactive_border = rgba(45475aaa)
    
    layout = dwindle
}

# Decoration
decoration {
    rounding = 8
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
}

# Animations
animations {
    enabled = true
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout
dwindle {
    pseudotile = true
    preserve_split = true
}

# Misc
misc {
    force_default_wallpaper = 0
}

# Keybinds
$mainMod = SUPER

bind = $mainMod, Q, exec, alacritty
bind = $mainMod, C, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, nautilus
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace with mainMod + Shift + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Screenshots
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = SHIFT, Print, exec, grim - | wl-copy
EOF
            echo "Created default hyprland config"
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
    
    if proof_command "Hyprland" || proof_command "hyprland"; then
        echo "✓ hyprland is installed"
    else
        echo "✗ hyprland not found"
        return 1
    fi
    
    # Check version
    local version
    version=$(hyprctl version 2>/dev/null | head -1)
    echo "  Version: $version"
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "hyprland has been installed."
    echo ""
    echo "To start hyprland:"
    echo "  Hyprland"
    echo ""
    echo "Key commands:"
    echo "  hyprctl              # Control hyprland"
    echo "  hyprpm               # Plugin manager"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/hypr/hyprland.conf"
}
