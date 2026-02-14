#!/bin/bash
# =============================================================================
# Module: udev
# =============================================================================
# udev - device management for Linux kernel
# =============================================================================

MODULE_NAME="udev"
MODULE_DESCRIPTION="Device management (udev)"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=()

MODULE_PROVIDES=(
    "system:device"
    "system:hotplug"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# udev packages - usually part of systemd on modern distros
MODULE_PACKAGES[arch]="systemd"
MODULE_PACKAGES[debian]="systemd udev"
MODULE_PACKAGES[ubuntu]="systemd udev"
MODULE_PACKAGES[fedora]="systemd-udev"
MODULE_PACKAGES[opensuse]="systemd udev"
MODULE_PACKAGES[alpine]="udev"
MODULE_PACKAGES[void]="eudev"
MODULE_PACKAGES[gentoo]="sys-fs/udev"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check udevd
    echo "  [PROOF] Checking udevd..."
    proof_command "udevd" || proof_command "systemd-udevd" || result=1
    
    # Proof Level 2: Check udevadm
    echo "  [PROOF] Checking udevadm..."
    proof_command "udevadm" || result=1
    
    # Proof Level 3: Check /dev
    echo "  [PROOF] Checking /dev directory..."
    if [[ -d "/dev" ]]; then
        echo "  [PROOF] ✓ /dev exists"
    else
        echo "  [PROOF] ✗ /dev not found"
        result=1
    fi
    
    # Proof Level 4: Check udev rules
    echo "  [PROOF] Checking udev rules..."
    if [[ -d "/etc/udev/rules.d" ]] || [[ -d "/lib/udev/rules.d" ]]; then
        echo "  [PROOF] ✓ udev rules directories exist"
    else
        echo "  [PROOF] ! udev rules directories not found"
    fi
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local distro
    distro=$(distro_detect)
    local init
    init=$(init_detect)
    
    echo "Detected: distro=$distro, init=$init"
    
    # Get packages for this distro
    local packages="${MODULE_PACKAGES[$distro]}"
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for distro: $distro"
        echo "Supported distros: ${!MODULE_PACKAGES[*]}"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Reload udev rules
    echo "Reloading udev..."
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    # Check udevd is running
    if proof_process "udevd" || proof_process "systemd-udevd"; then
        echo "✓ udevd is running"
    else
        echo "✗ udevd is not running"
        return 1
    fi
    
    # Test udevadm
    if udevadm info --export-db >/dev/null 2>&1; then
        echo "✓ udev database is populated"
    else
        echo "✗ udev database not populated"
        return 1
    fi
    
    # Check device nodes
    local device_count
    device_count=$(ls -1 /dev 2>/dev/null | wc -l)
    if [[ "$device_count" -gt 10 ]]; then
        echo "✓ Device nodes present ($device_count entries)"
    else
        echo "⚠ Few device nodes found"
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "udev has been installed."
    echo ""
    echo "Key commands:"
    echo "  udevadm info          # Query device information"
    echo "  udevadm trigger      # Trigger device events"
    echo "  udevadm control      # Control udev daemon"
    echo "  ls /dev              # List device nodes"
    echo ""
    echo "Configuration:"
    echo "  /etc/udev/rules.d/   # Local udev rules"
    echo "  /lib/udev/rules.d/   # System udev rules"
}
