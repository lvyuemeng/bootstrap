#!/bin/bash
# =============================================================================
# Module: wayland
# =============================================================================
# Wayland display server protocol and library
# =============================================================================

MODULE_NAME="wayland"
MODULE_DESCRIPTION="Wayland display server protocol"

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
)

MODULE_PROVIDES=(
    "display:protocol"
)

# =============================================================================
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

MODULE_PACKAGES[pacman]="wayland"
MODULE_PACKAGES[apt]="libwayland-dev wayland-protocols"
MODULE_PACKAGES[dnf]="wayland-devel wayland-protocols"
MODULE_PACKAGES[zypper]="wayland-devel"
MODULE_PACKAGES[apk]="wayland-dev wayland-protocols"
MODULE_PACKAGES[xbps]="wayland"
MODULE_PACKAGES[emerge]="dev-libs/wayland"

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    
    local packages="${MODULE_PACKAGES[$pkgmgr]}"
    
    if [[ -z "$packages" ]]; then
        echo "No packages defined for pkgmgr: $pkgmgr"
        return 1
    fi
    
    pkg_install "$packages" "$pkgmgr"
}

# =============================================================================
# PROOFS
# =============================================================================

module_proofs() {
    proof_command "weston" || true
    proof_file "/usr/share/wayland/wayland.xml" || true
}
