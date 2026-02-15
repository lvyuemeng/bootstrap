#!/bin/bash
# =============================================================================
# Module: qpwgraph
# =============================================================================
# qpwgraph - PipeWire graph control
# =============================================================================

MODULE_NAME="qpwgraph"
MODULE_DESCRIPTION="PipeWire graph control"

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

MODULE_REQUIRES=( "audio-pipewire" )
MODULE_PROVIDES=( "audio:gui" )

declare -A MODULE_PACKAGES
MODULE_PACKAGES[pacman]="qpwgraph"
MODULE_PACKAGES[apt]="qpwgraph"
MODULE_PACKAGES[dnf]="qpwgraph"
MODULE_PACKAGES[zypper]="qpwgraph"
MODULE_PACKAGES[apk]="qpwgraph"
MODULE_PACKAGES[xbps]="qpwgraph"
MODULE_PACKAGES[emerge]="qpwgraph"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "qpwgraph" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    pkg_install "${MODULE_PACKAGES[$pkgmgr]}" "$pkgmgr"
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "qpwgraph" && echo "✓ qpwgraph installed"
}

module_info() {
    echo "qpwgraph installed."
    echo "Run: qpwgraph"
}
