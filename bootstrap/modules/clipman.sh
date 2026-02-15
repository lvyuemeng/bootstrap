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
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

MODULE_PACKAGES[pacman]="clipman"
MODULE_PACKAGES[apt]="clipman"
MODULE_PACKAGES[dnf]="clipman"
MODULE_PACKAGES[zypper]="clipman"
MODULE_PACKAGES[apk]="clipman"
MODULE_PACKAGES[xbps]="clipman"
MODULE_PACKAGES[emerge]="clipman"

# =============================================================================
# PROOF & INSTALL
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "clipman" || return 1
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
    autostart_add "clipman" 2>/dev/null || true
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "clipman" && echo "✓ clipman installed"
}

module_info() {
    echo "clipman installed. Run: clipman"
}
