#!/bin/bash
# =============================================================================
# Module: xsel
# =============================================================================
# xsel - Clipboard tools for X11
# =============================================================================

MODULE_NAME="xsel"
MODULE_DESCRIPTION="Clipboard tools (X11)"

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

MODULE_REQUIRES=( "x11-server" )
MODULE_PROVIDES=( "desktop:clipboard" )

declare -A MODULE_PACKAGES
MODULE_PACKAGES[pacman]="xsel"
MODULE_PACKAGES[apt]="xsel"
MODULE_PACKAGES[dnf]="xsel"
MODULE_PACKAGES[zypper]="xsel"
MODULE_PACKAGES[apk]="xsel"
MODULE_PACKAGES[xbps]="xsel"
MODULE_PACKAGES[emerge]="xsel"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "xsel" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    pkg_install "${MODULE_PACKAGES[$pkgmgr]}" "$pkgmgr"
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "xsel" && echo "✓ xsel installed"
}

module_info() {
    echo "xsel installed."
}
