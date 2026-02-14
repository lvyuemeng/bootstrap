#!/bin/bash
# =============================================================================
# Module: wl-paste
# =============================================================================
# wl-paste - Clipboard tools for Wayland
# =============================================================================

MODULE_NAME="wl-paste"
MODULE_DESCRIPTION="Clipboard tools (Wayland)"

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

MODULE_PACKAGES[arch]="wl-clipboard"
MODULE_PACKAGES[debian]="wl-clipboard"
MODULE_PACKAGES[ubuntu]="wl-clipboard"
MODULE_PACKAGES[fedora]="wl-clipboard"
MODULE_PACKAGES[opensuse]="wl-clipboard"

# =============================================================================
# PROOF & INSTALL
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "wl-paste" || return 1
    proof_command "wl-copy" || return 1
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
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "wl-paste" && echo "✓ wl-paste installed"
    proof_command "wl-copy" && echo "✓ wl-copy installed"
}

module_info() {
    echo "wl-clipboard installed."
    echo "Commands: wl-copy, wl-paste"
}
