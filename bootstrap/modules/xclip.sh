#!/bin/bash
# =============================================================================
# Module: xclip
# =============================================================================
# xclip - Clipboard tools for X11
# =============================================================================

MODULE_NAME="xclip"
MODULE_DESCRIPTION="Clipboard tools (X11)"

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

MODULE_REQUIRES=( "x11-server" )
MODULE_PROVIDES=( "desktop:clipboard" )

declare -A MODULE_PACKAGES
MODULE_PACKAGES[pacman]="xclip"
MODULE_PACKAGES[apt]="xclip"
MODULE_PACKAGES[dnf]="xclip"
MODULE_PACKAGES[zypper]="xclip"
MODULE_PACKAGES[apk]="xclip"
MODULE_PACKAGES[xbps]="xclip"
MODULE_PACKAGES[emerge]="xclip"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "xclip" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    pkg_install "${MODULE_PACKAGES[$pkgmgr]}" "$pkgmgr"
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "xclip" && echo "✓ xclip installed"
}

module_info() {
    echo "xclip installed. Run: xclip -selection clipboard"
}
