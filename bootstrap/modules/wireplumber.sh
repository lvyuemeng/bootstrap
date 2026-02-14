#!/bin/bash
# =============================================================================
# Module: wireplumber
# =============================================================================
# wireplumber - PipeWire session manager
# =============================================================================

MODULE_NAME="wireplumber"
MODULE_DESCRIPTION="PipeWire session manager"

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

MODULE_REQUIRES=( "audio-pipewire" )
MODULE_PROVIDES=( "audio:session-manager" )

declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="wireplumber"
MODULE_PACKAGES[debian]="wireplumber"
MODULE_PACKAGES[ubuntu]="wireplumber"
MODULE_PACKAGES[fedora]="wireplumber"
MODULE_PACKAGES[opensuse]="wireplumber"
MODULE_PACKAGES[alpine]="wireplumber"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "wireplumber" || return 1
    proof_process "wireplumber" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local distro
    distro=$(distro_detect)
    pkg_install "${MODULE_PACKAGES[$distro]}"
    
    # Enable autostart
    autostart_add "wireplumber" 2>/dev/null || true
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "wireplumber" && echo "✓ wireplumber installed"
    proof_process "wireplumber" && echo "✓ wireplumber running"
}

module_info() {
    echo "wireplumber installed."
    echo "Run: wireplumber"
}
