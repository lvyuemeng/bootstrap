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
MODULE_PACKAGES[arch]="qpwgraph"
MODULE_PACKAGES[debian]="qpwgraph"
MODULE_PACKAGES[ubuntu]="qpwgraph"
MODULE_PACKAGES[fedora]="qpwgraph"
MODULE_PACKAGES[opensuse]="qpwgraph"

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    proof_command "qpwgraph" || return 1
}

module_install() {
    echo "Installing $MODULE_NAME..."
    local distro
    distro=$(distro_detect)
    pkg_install "${MODULE_PACKAGES[$distro]}"
    echo "$MODULE_NAME installed"
}

module_verify() {
    proof_command "qpwgraph" && echo "✓ qpwgraph installed"
}

module_info() {
    echo "qpwgraph installed."
    echo "Run: qpwgraph"
}
