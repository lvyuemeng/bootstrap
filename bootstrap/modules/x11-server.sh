#!/bin/bash
# =============================================================================
# Module: x11-server
# =============================================================================
# X11/Xorg display server - traditional Linux graphics
# =============================================================================

MODULE_NAME="x11-server"
MODULE_DESCRIPTION="X11/Xorg display server"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "dbus"
    "init"
)

MODULE_PROVIDES=(
    "display:server"
    "graphics:x11"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Xorg packages
MODULE_PACKAGES[arch]="xorg-server xorg-xinit xorg-apps xorg-drivers"
MODULE_PACKAGES[debian]="xorg xorg-apps xserver-xorg-video-all"
MODULE_PACKAGES[ubuntu]="xorg xorg-apps xserver-xorg-video-all"
MODULE_PACKAGES[fedora]="xorg-x11-server-Xorg xorg-x11-apps xorg-x11-drivers"
MODULE_PACKAGES[opensuse]="xorg-x11-server xorg-x11-apps xorg-x11-driver-video"
MODULE_PACKAGES[alpine]="xorg-server xorg-xinit xorg-apps"
MODULE_PACKAGES[void]="xorg-server xorg-xinit xorg-apps"
MODULE_PACKAGES[gentoo]="x11-base/xorg-server x11-apps/xinit"

# Virtual display (for headless)
declare -A MODULE_PACKAGESXVFB
MODULE_PACKAGESXVFB[arch]="xvfb"
MODULE_PACKAGESXVFB[debian]="xvfb"
MODULE_PACKAGESXVFB[ubuntu]="xvfb"
MODULE_PACKAGESXVFB[fedora]="xorg-x11-server-Xvfb"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check Xorg command
    echo "  [PROOF] Checking Xorg..."
    proof_command "Xorg" || result=1
    
    # Proof Level 2: Check startx
    echo "  [PROOF] Checking startx..."
    proof_command "startx" || result=1
    
    # Proof Level 3: Check xinit
    echo "  [PROOF] Checking xinit..."
    proof_command "xinit" || result=1
    
    # Proof Level 4: Check XDG_RUNTIME_DIR
    echo "  [PROOF] Checking XDG_RUNTIME_DIR..."
    if [[ -n "$XDG_RUNTIME_DIR" ]]; then
        echo "  [PROOF] ✓ XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    else
        echo "  [WARN] XDG_RUNTIME_DIR not set"
    fi
    
    # Proof Level 5: Check /etc/X11 directory
    echo "  [PROOF] Checking X11 config directory..."
    if [[ -d "/etc/X11" ]]; then
        echo "  [PROOF] ✓ /etc/X11 exists"
    else
        echo "  [WARN] /etc/X11 not found"
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
    
    # Configure X11
    configure_x11
    
    # Setup xinitrc
    setup_xinitrc
    
    # Setup xprofile
    setup_xprofile
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# CONFIGURE X11
# =============================================================================

configure_x11() {
    echo "Configuring X11..."
    
    # Create XDG directories
    mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/X11"
    
    # Check for user config in dotfiles
    local dotfiles_x11="$CONFIG_DOTFILES_DIR/.config/X11"
    
    if [[ -d "$dotfiles_x11" ]]; then
        echo "Using user's X11 config from dotfiles"
    else
        # Create default xorg.conf.d if not exists
        if [[ ! -d "/etc/X11/xorg.conf.d" ]]; then
            sudo mkdir -p /etc/X11/xorg.conf.d
        fi
    fi
}

# =============================================================================
# SETUP XINITRC
# =============================================================================

setup_xinitrc() {
    local xinitrc="${HOME}/.xinitrc"
    local dotfiles_xinitrc="$CONFIG_DOTFILES_DIR/.xinitrc"
    
    if [[ -f "$dotfiles_xinitrc" ]]; then
        echo "Using user's .xinitrc from dotfiles"
        config_link "$xinitrc"
    else
        # Create basic .xinitrc if none exists
        if [[ ! -f "$xinitrc" ]]; then
            cat > "$xinitrc" <<'EOF'
#!/bin/sh
# ~/.xinitrc - executed by startx

# Load X resources
[[ -f ~/.Xresources ]] && xrdb ~/.Xresources

# Set keyboard rate
xset r rate 250 30 2>/dev/null

# Start desktop/wm (user should edit this)
# exec i3
# exec startplasma-x11
# exec gnome-session
# exec startxfce4

# Default: just echo message
echo "Edit ~/.xinitrc to start your window manager"
EOF
            chmod +x "$xinitrc"
            echo "Created default .xinitrc"
        fi
    fi
}

# =============================================================================
# SETUP XPROFILE
# =============================================================================

setup_xprofile() {
    local xprofile="${HOME}/.xprofile"
    local dotfiles_xprofile="$CONFIG_DOTFILES_DIR/.xprofile"
    
    if [[ -f "$dotfiles_xprofile" ]]; then
        echo "Using user's .xprofile from dotfiles"
        config_link "$xprofile"
    else
        # Create basic .xprofile if none exists
        if [[ ! -f "$xprofile" ]]; then
            cat > "$xprofile" <<'EOF'
#!/bin/sh
# ~/.xprofile - executed by display manager (if used)

# Set default cursor
xsetroot -cursor_name left_ptr

# Enable numlock
numlockx on 2>/dev/null

# Export XDG variables
export XDG_CURRENT_DESKTOP=generic
export XDG_SESSION_TYPE=x11
EOF
            chmod +x "$xprofile"
            echo "Created default .xprofile"
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
    
    # Check X version
    echo ""
    echo "X11 version:"
    Xorg -version 2>&1 || true
    
    # Check available drivers
    echo ""
    echo "Available video drivers:"
    ls -la /usr/lib/xorg/modules/drivers/ 2>/dev/null || ls -la /usr/lib64/xorg/modules/drivers/ 2>/dev/null || true
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

Starting X11:
  startx              # From console
  xinit               # Same as startx

Configuration:
  /etc/X11/xorg.conf       # Main config (usually auto-detected)
  /etc/X11/xorg.conf.d/    # Fragment configs
  ~/.xinitrc               # Your session (edit this!)
  ~/.xprofile              # Display manager config
  ~/.Xresources           # X resources

Common Video Drivers:
  modesetting          # Kernel modesetting (default)
  intel                # Intel iGPU
  amdgpu               # AMD GPU
  nouveau              # NVIDIA open source
  nvidia               # NVIDIA proprietary
  vboxvideo            # VirtualBox
  vmware               # VMware

Common Fixes:
  # Screen blanking
  xset s off
  xset -dpms
  xset s noblank
  
  # Resolution
  xrandr --output HDMI-1 --mode 1920x1080
  
  # Multiple monitors
  xrandr --output HDMI-1 --right-of DP-1
  
  # DPI
  xrandr --dpi 96
  
  # Touchpad
  xinput list
  xinput set-prop "Synaptics" "libinput Tapping Enabled" 1

Session Start Examples:
  exec i3                  # i3 window manager
  exec openbox-session    # Openbox
  exec startplasma-x11    # KDE Plasma
  exec gnome-session      # GNOME
  exec startxfce4         # XFCE

Proof Chain:
  Level 1: Xorg command available
  Level 2: startx command available
  Level 3: xinit command available
  Level 4: XDG_RUNTIME_DIR set
  Level 5: /etc/X11 exists

EOF
}
