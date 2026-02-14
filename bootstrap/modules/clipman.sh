#!/bin/bash
# =============================================================================
# Module: clipman
# =============================================================================
# clipman - Clipboard manager for Wayland
# =============================================================================

MODULE_NAME="clipman"
MODULE_DESCRIPTION="Clipboard manager (Wayland)"

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
    "desktop:clipboard"
)

# =============================================================================
# PACKAGE ADAPTATION
# =============================================================================

declare -A MODULE_PACKAGES

MODULE_PACKAGES[arch]="clipman"
MODULE_PACKAGES[debian]="clipman"
MODULE_PACKAGES[ubuntu]="clipman"
MODULE_PACKAGES[fedora]="clipman"
MODULE_PACKAGES[opensuse]="clipman"

# =============================================================================
# PROOF & INSTALL
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "clipman" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local distro
    distro=$(distro_detect)
    local packages="${MODULE_PACKAGES[$distro]}"
    
    if [[ -z "$packages" ]]; then
        echo "No packages for $distro"
        return 1
    fi
    
    pkg_install "$packages"
    autostart_add "clipman" 2>/dev/null || true
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "clipman" && echo "✓ clipman installed"
}

module_info() {
    echo "clipman installed. Run: clipman"
}
