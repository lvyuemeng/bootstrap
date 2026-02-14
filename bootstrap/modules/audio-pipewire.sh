#!/bin/bash
# =============================================================================
# Module: audio-pipewire
# =============================================================================
# PipeWire audio server - modern audio replacement for PulseAudio
# Uses distro.sh library for package/service management
# =============================================================================

MODULE_NAME="audio-pipewire"
MODULE_DESCRIPTION="PipeWire audio server"

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
    "audio:server"
    "audio:pulse-compat"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Core PipeWire packages
MODULE_PACKAGES[arch]="pipewire pipewire-pulse pipewire-alsa wireplumber lib32-pipewire lib32-pipewire-pulse"
MODULE_PACKAGES[debian]="pipewire pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack"
MODULE_PACKAGES[ubuntu]="pipewire pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack"
MODULE_PACKAGES[fedora]="pipewire pipewire-pulse pipewire-alsa wireplumber"
MODULE_PACKAGES[opensuse]="pipewire pipewire-pulse pipewire-alsa"
MODULE_PACKAGES[alpine]="pipewire pipewire-pulse"
MODULE_PACKAGES[void]="pipewire pipewire-pulse"
MODULE_PACKAGES[gentoo]="media-video/pipewire media-video/wireplumber"

# Optional: JACK support
declare -A MODULE_PACKAGES_JACK
MODULE_PACKAGES_JACK[arch]="jack2"
MODULE_PACKAGES_JACK[debian]="jackd"
MODULE_PACKAGES_JACK[fedora]="jack-audio-connection-kit"

# =============================================================================
# SERVICE DEFINITION
# =============================================================================

MODULE_SERVICE_NAME="pipewire"
MODULE_SERVICE_PULSE="pipewire-pulse"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check pipewire command
    echo "  [PROOF] Checking pipewire..."
    proof_command "pipewire" || result=1
    
    # Proof Level 2: Check pipewire-pulse (pulse compat)
    echo "  [PROOF] Checking pipewire-pulse..."
    if command -v pipewire-pulse >/dev/null 2>&1; then
        echo "  [PROOF] ✓ pipewire-pulse available"
    else
        echo "  [WARN] pipewire-pulse not found"
    fi
    
    # Proof Level 3: Check wireplumber (session manager)
    echo "  [PROOF] Checking wireplumber..."
    if command -v wireplumber >/dev/null 2>&1 || command -v wpctl >/dev/null 2>&1; then
        echo "  [PROOF] ✓ wireplumber available"
    else
        echo "  [WARN] wireplumber not found"
    fi
    
    # Proof Level 4: Check processes
    echo "  [PROOF] Checking processes..."
    proof_process "pipewire" || {
        echo "  [WARN] pipewire process not running"
        result=1
    }
    
    # Proof Level 5: Check D-Bus
    echo "  [PROOF] Checking D-Bus..."
    proof_dbus_service "org.PulseAudio.Server" || {
        echo "  [WARN] PulseAudio D-Bus not available (may be OK)"
    }
    
    # Proof Level 6: Check ALSA
    echo "  [PROOF] Checking ALSA..."
    if [[ -c "/dev/snd/controlC0" ]] || [[ -c "/dev/snd/"* ]]; then
        echo "  [PROOF] ✓ ALSA devices available"
    else
        echo "  [INFO] No ALSA devices found (may need drivers)"
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
    
    # Configure PipeWire session manager
    configure_pipewire
    
    # Setup user audio groups
    setup_audio_groups
    
    # Create client config directory
    mkdir -p "${HOME}/.config/pipewire"
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# CONFIGURE PIPEWIRE
# =============================================================================

configure_pipewire() {
    local config_dir="${HOME}/.config/pipewire"
    mkdir -p "$config_dir"
    
    # Check for user-provided config in dotfiles
    local dotfiles_pw_dir="$CONFIG_DOTFILES_DIR/.config/pipewire"
    
    if [[ -d "$dotfiles_pw_dir" ]]; then
        echo "Using user's PipeWire config from dotfiles"
        config_link "$config_dir/pipewire.conf" 2>/dev/null || true
    else
        # Create minimal user config that inherits system config
        if [[ ! -f "$config_dir/pipewire.conf" ]]; then
            cat > "$config_dir/pipewire.conf" <<'EOF'
# User PipeWire configuration
# This inherits from /etc/pipewire/
# Add custom modifications here

# Include system defaults
# /etc/pipewire/pipewire.conf will be loaded if this file is empty
EOF
        fi
    fi
    
    # Configure PulseAudio compatibility
    local pulse_dir="${HOME}/.config/pulse"
    mkdir -p "$pulse_dir"
    
    if [[ ! -f "$pulse_dir/default.pa" ]]; then
        cat > "$pulse_dir/default.pa" <<'EOF'
# PulseAudio configuration for PipeWire compatibility
# Loaded by pipewire-pulse

load-module module-native-protocol-unix
load-module module-default-sink-set
load-module module-always-sink

# Set default sink
set-default-sink @DEFAULT_SINK@
EOF
    fi
}

# =============================================================================
# SETUP AUDIO GROUPS
# =============================================================================

setup_audio_groups() {
    # Add user to audio group if not already a member
    if groups | grep -q audio; then
        echo "User already in audio group"
    else
        echo "Note: You may need to add your user to the audio group:"
        echo "  sudo usermod -aG audio $USER"
        echo "  (or: sudo gpasswd -a $USER audio)"
        echo "  Then logout and login again"
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
    
    # Check pw-cli (PipeWire CLI)
    if command -v pw-cli >/dev/null 2>&1; then
        echo ""
        echo "PipeWire nodes:"
        pw-cli list-objects 2>/dev/null | grep -E "node|adapter" | head -10 || true
    fi
    
    # Check wpctl (WirePlumber CLI)
    if command -v wpctl >/dev/null 2>&1; then
        echo ""
        echo "Audio sinks:"
        wpctl audio-get-sinks 2>/dev/null || true
    fi
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

Architecture:
  Applications → PipeWire → ALSA (kernel)
                      ↓
              wireplumber (session manager)
                      ↓
              PulseAudio compatibility layer

Usage:
  pw-cli list-objects       # List PipeWire objects
  wpctl audio-get-sinks     # List audio outputs
  wpctl set-default-sink ID # Set default output
  wpctl set-default-source ID # Set default input
  pw-top                    # Show PipeWire graph

Configuration:
  ~/.config/pipewire/pipewire.conf
  ~/.config/pulse/default.pa (PipeWire compat)

Environment Variables:
  PIPEWIRE_DEBUG=1         # Enable debug output
  PULSE_SERVER=unix:/run/user/1000/pulse/native

Service Management:
  systemctl --user enable pipewire pipewire-pulse
  systemctl --user start pipewire pipewire-pulse

Proof Chain:
  Level 1: pipewire command available
  Level 2: pipewire-pulse available
  Level 3: wireplumber available
  Level 4: pipewire process running
  Level 5: D-Bus service available
  Level 6: ALSA devices accessible

To switch from PulseAudio:
  1. Stop pulseaudio: pulseaudio --kill
  2. Start pipewire: pipewire &
  3. Start pipewire-pulse: pipewire-pulse &
  4. Restart applications

EOF
}
