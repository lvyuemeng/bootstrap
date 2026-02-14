#!/bin/bash
# =============================================================================
# Module: audio-pulseaudio
# =============================================================================
# PulseAudio - Legacy audio server
# =============================================================================

MODULE_NAME="audio-pulseaudio"
MODULE_DESCRIPTION="PulseAudio (legacy audio server)"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "audio-alsa"
)

MODULE_PROVIDES=(
    "audio:server"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# PulseAudio packages
MODULE_PACKAGES[arch]="pulseaudio pulseaudio-alsa"
MODULE_PACKAGES[debian]="pulseaudio pulseaudio-utils libpulse-mainloop-glib0"
MODULE_PACKAGES[ubuntu]="pulseaudio pulseaudio-utils"
MODULE_PACKAGES[fedora]="pulseaudio pulseaudio-utils"
MODULE_PACKAGES[opensuse]="pulseaudio pulseaudio-utils"
MODULE_PACKAGES[alpine]="pulseaudio"
MODULE_PACKAGES[void]="pulseaudio"
MODULE_PACKAGES[gentoo]="media-sound/pulseaudio"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check pulseaudio binary
    echo "  [PROOF] Checking pulseaudio..."
    proof_command "pulseaudio" || result=1
    
    # Proof Level 2: Check pactl
    echo "  [PROOF] Checking pactl..."
    proof_command "pactl" || result=1
    
    # Proof Level 3: Check running
    echo "  [PROOF] Checking pulseaudio process..."
    proof_process "pulseaudio" || result=1
    
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
    
    # Setup PulseAudio config
    setup_pulse_config
    
    # Enable PulseAudio service if needed
    setup_pulse_service
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# SETUP PULSEAUDIO CONFIG
# =============================================================================

setup_pulse_config() {
    local config_dir="${HOME}/.config/pulse"
    
    # Find user's config
    local user_config
    user_config=$(config_find "pulse")
    
    config_ensure_dir "$config_dir"
    
    if [[ -n "$user_config" ]]; then
        if [[ -d "$user_config" ]]; then
            config_link_dir "$user_config" "$config_dir"
        else
            config_link "$user_config" "${config_dir}/default.pa"
        fi
        echo "Using user's pulse config from dotfiles"
    else
        # Create default config if not exists
        if [[ ! -f "${config_dir}/default.pa" ]]; then
            cat > "${config_dir}/default.pa" << 'EOF'
# Load the native protocol module
load-module module-native-protocol-unix

# Load the system-wide protocol module (for system-wide instance)
# load-module module-native-protocol-tcp

# Load the redirect sink/source
load-module module-null-sink
load-module module-null-sink sink_name=virtual_output sink_properties=device.description="Virtual_Output"

# Automatically restore the default sink/source
load-module module-default-device-restore

# Automatically restore the volume of streams
load-module module-volume-restore

# Automatically suspend sinks/sources that become idle
load-module module-suspend-on-idle

# Enable the D-Bus module (for media keys)
load-module module-dbus-protocol
EOF
            echo "Created default PulseAudio config"
        fi
    fi
}

# =============================================================================
# SETUP PULSEAUDIO SERVICE
# =============================================================================

setup_pulse_service() {
    local init
    init=$(init_detect)
    
    case "$init" in
        systemd)
            # Some distros use user-level pulseaudio, others use system
            # Try to start it as user
            echo "Note: PulseAudio typically runs as user session"
            ;;
    esac
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_command "pulseaudio"; then
        echo "✓ pulseaudio is installed"
    else
        echo "✗ pulseaudio not found"
        return 1
    fi
    
    # Check if running
    if proof_process "pulseaudio"; then
        echo "✓ pulseaudio is running"
    else
        echo "Note: pulseaudio not running (will start on first use)"
    fi
    
    # Test pactl
    if pactl info >/dev/null 2>&1; then
        echo "✓ pulseaudio is functional"
    else
        echo "⚠ pulseaudio not functional yet"
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "PulseAudio has been installed."
    echo ""
    echo "Note: Consider using PipeWire (audio-pipewire module) instead."
    echo "PulseAudio is in maintenance mode."
    echo ""
    echo "Key commands:"
    echo "  pactl              # Control pulseaudio"
    echo "  pavucontrol       # Volume control GUI"
    echo "  paplay            # Play audio file"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/pulse/default.pa"
}
