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
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

MODULE_PACKAGES[pacman]="wl-clipboard"
MODULE_PACKAGES[apt]="wl-clipboard"
MODULE_PACKAGES[dnf]="wl-clipboard"
MODULE_PACKAGES[zypper]="wl-clipboard"
MODULE_PACKAGES[apk]="wl-clipboard"
MODULE_PACKAGES[xbps]="wl-clipboard"
MODULE_PACKAGES[emerge]="wl-clipboard"

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
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    local packages="${MODULE_PACKAGES[$pkgmgr]}"
    
    if [[ -z "$packages" ]]; then
        echo "No packages for $pkgmgr"
        return 1
    fi
    
    pkg_install "$packages" "$pkgmgr"
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
