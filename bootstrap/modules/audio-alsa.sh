#!/bin/bash
# =============================================================================
# Module: audio-alsa
# =============================================================================
# ALSA sound drivers - low-level Linux audio interface
# Note: Usually already in kernel, but we provide user-space tools
# =============================================================================

MODULE_NAME="audio-alsa"
MODULE_DESCRIPTION="ALSA sound drivers and utilities"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "kernel"
)

MODULE_PROVIDES=(
    "audio:drivers"
    "audio:device"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Core ALSA utilities
MODULE_PACKAGES[arch]="alsa-utils alsa-lib lib32-alsa-lib lib32-alsa-utils"
MODULE_PACKAGES[debian]="alsa-utils libasound2 libasound2-plugins"
MODULE_PACKAGES[ubuntu]="alsa-utils libasound2 libasound2-plugins"
MODULE_PACKAGES[fedora]="alsa-utils alsa-lib"
MODULE_PACKAGES[opensuse]="alsa-tools alsa-utils alsa-plugins"
MODULE_PACKAGES[alpine]="alsa-utils"
MODULE_PACKAGES[void]="alsa-utils"
MODULE_PACKAGES[gentoo]="media-sound/alsa-utils media-libs/alsa-lib"

# Firmware packages (for specific sound cards)
declare -A MODULE_PACKAGES_FIRMWARE
MODULE_PACKAGES_FIRMWARE[arch]="alsa-firmware"
MODULE_PACKAGES_FIRMWARE[debian]="alsa-firmware"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check ALSA device nodes
    echo "  [PROOF] Checking ALSA device nodes..."
    if [[ -c "/dev/snd/controlC0" ]] || ls /dev/snd/controlC* >/dev/null 2>&1; then
        echo "  [PROOF] ✓ ALSA control device found"
        ls -la /dev/snd/ 2>/dev/null || true
    else
        echo "  [WARN] No ALSA control devices found"
        echo "  This usually means:"
        echo "    - Sound card not detected"
        echo "    - Kernel module not loaded"
        echo "    - Run: sudo modprobe snd-hda-intel (or your codec)"
    fi
    
    # Proof Level 2: Check aplay command
    echo "  [PROOF] Checking aplay..."
    proof_command "aplay" || result=1
    
    # Proof Level 3: Check amixer command
    echo "  [PROOF] Checking amixer..."
    proof_command "amixer" || result=1
    
    # Proof Level 4: Check ALSA library
    echo "  [PROOF] Checking ALSA library..."
    if [[ -f "/usr/lib/libasound.so" ]] || [[ -f "/usr/lib64/libasound.so" ]]; then
        echo "  [PROOF] ✓ ALSA library found"
    else
        echo "  [WARN] ALSA library not found"
    fi
    
    # Proof Level 5: List available cards
    echo "  [PROOF] Checking sound cards..."
    if command -v aplay >/dev/null 2>&1; then
        aplay -l 2>/dev/null || echo "  [INFO] No sound cards listed"
    fi
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local distro
    distro=$(dist   ro_detect)
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
    
    # Load ALSA modules
    load_alsa_modules
    
    # Configure user-level ALSA
    configure_alsa
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# LOAD ALSA KERNEL MODULES
# =============================================================================

load_alsa_modules() {
    echo "Checking ALSA kernel modules..."
    
    # Check if already loaded
    if lsmod | grep -q snd; then
        echo "ALSA modules already loaded:"
        lsmod | grep snd
        return 0
    fi
    
    echo "ALSA kernel modules not loaded."
    echo ""
    echo "To load manually, run:"
    echo "  sudo modprobe snd-hda-intel    # For most Intel/AMD onboard audio"
    echo "  sudo modprobe snd-usb-audio   # For USB audio devices"
    echo "  sudo modprobe snd-emu10k1     # For Sound Blaster cards"
    echo ""
    echo "To load at boot, create /etc/modprobe.d/alsa.conf:"
    echo "  options snd-hda-intel model=auto"
    echo ""
    echo "Common module options:"
    echo "  snd-hda-intel model=    # Fix specific codec issues"
    echo "  snd-usb-audio index=    # Set device order"
}

# =============================================================================
# CONFIGURE USER ALSA
# =============================================================================

configure_alsa() {
    local config_dir="${HOME}/.config/alsa"
    mkdir -p "$config_dir"
    
    # Check for user-provided config in dotfiles
    local dotfiles_alsa_dir="$CONFIG_DOTFILES_DIR/.config/alsa"
    
    if [[ -f "$dotfiles_alsa_dir/asoundrc" ]]; then
        echo "Using user's ALSA config from dotfiles"
    else
        # Create basic ALSA config if none exists
        local asoundrc="${HOME}/.asoundrc"
        if [[ ! -f "$asoundrc" ]]; then
            cat > "$asoundrc" <<'EOF'
# ALSA configuration file
# User-specific config: ~/.asoundrc
# System-wide: /etc/asound.conf

# Default to hardware default
pcm.!default {
    type hw
    card 0
}

# Allow PulseAudio to work alongside ALSA
ctl.!default {
    type hw
    card 0
}
EOF
        fi
    fi
    
    # Create alsa.conf in config dir
    cat > "$config_dir/alsa.conf" <<'EOF'
# ALSA configuration
# Include system config
@include /etc/alsa/conf.d

# Default PCM device
pcm.default "plug:default"

# Default control
ctl.default {
    type hw
    card 0
}
EOF
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
    
    # Test basic functionality
    echo ""
    echo "Testing ALSA:"
    
    # List cards
    if command -v aplay >/dev/null 2>&1; then
        echo "Available sound cards:"
        aplay -l 2>&1 || true
        
        echo ""
        echo "Available PCM devices:"
        aplay -L 2>&1 | head -20 || true
    fi
    
    # Show mixer
    if command -v amixer >/dev/null 2>&1; then
        echo ""
        echo "Current mixer settings:"
        amixer 2>&1 | head -20 || true
    fi
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Note: ALSA consists of two parts:
  1. Kernel drivers (snd_*) - loaded via modprobe
  2. User-space tools (alsa-utils) - installed here

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

Usage:
  aplay -l                  # List sound cards
  aplay -L                  # List PCM devices
  amixer                    # Show mixer controls
  amixer set Master 50%     # Set volume
  speaker-test -t sine      # Test audio

Configuration:
  ~/.asoundrc               # User ALSA config
  /etc/asound.conf          # System ALSA config
  /etc/modprobe.d/          # Kernel module options

Kernel Modules:
  snd-hda-intel             # Intel/AMD HD Audio
  snd-usb-audio             # USB Audio
  snd-emu10k1               # Sound Blaster Live!
  snd-ac97-codec            # AC97 codec (legacy)

Common Fixes:
  # No sound
  sudo modprobe snd-hda-intel
  
  # Wrong device order
  options snd-usb-audio index=0
  
  # Headphones not working
  amixer set Headphone 100%
  
  # Digital output
  aplay -D hw:0,1 file.wav

Proof Chain:
  Level 1: ALSA device nodes in /dev/snd
  Level 2: aplay command available
  Level 3: amixer command available
  Level 4: ALSA library installed
  Level 5: Sound cards detected

EOF
}
