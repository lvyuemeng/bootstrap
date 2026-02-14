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
MODULE_PACKAGES[arch]="xclip"
MODULE_PACKAGES[debian]="xclip"
MODULE_PACKAGES[ubuntu]="xclip"
MODULE_PACKAGES[fedora]="xclip"
MODULE_PACKAGES[opensuse]="xclip"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "xclip" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local distro
    distro=$(distro_detect)
    pkg_install "${MODULE_PACKAGES[$distro]}"
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "xclip" && echo "✓ xclip installed"
}

module_info() {
    echo "xclip installed. Run: xclip -selection clipboard"
}
