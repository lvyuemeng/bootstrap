#!/bin/bash
# =============================================================================
# Module: pavucontrol
# =============================================================================
# pavucontrol - PulseAudio volume control
# =============================================================================

MODULE_NAME="pavucontrol"
MODULE_DESCRIPTION="PulseAudio volume control"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "audio-pulseaudio"
)

MODULE_PROVIDES=(
    "audio:control"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

MODULE_PACKAGES[arch]="pavucontrol"
MODULE_PACKAGES[debian]="pavucontrol"
MODULE_PACKAGES[ubuntu]="pavucontrol"
MODULE_PACKAGES[fedora]="pavucontrol"
MODULE_PACKAGES[opensuse]="pavucontrol"
MODULE_PACKAGES[alpine]="pavucontrol"
MODULE_PACKAGES[void]="pavucontrol"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    echo "  [PROOF] Checking pavucontrol..."
    proof_command "pavucontrol" || result=1
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local distro
    distro=$(distro_detect)
    
    local packages="${MODULE_PACKAGES[$distro]}"
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages for $distro"
        return 1
    fi
    
    echo "Installing: $packages"
    pkg_install "$packages"
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    if proof_command "pavucontrol"; then
        echo "✓ pavucontrol installed"
        return 0
    fi
    return 1
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "pavucontrol installed."
    echo "Run: pavucontrol"
}
