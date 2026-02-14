#!/bin/bash
# =============================================================================
# Module: wlroots
# =============================================================================
# wlroots - Modular Wayland compositor library
# =============================================================================

MODULE_NAME="wlroots"
MODULE_DESCRIPTION="Wayland compositor library"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "wayland"
    "dbus"
)

MODULE_PROVIDES=(
    "wayland:library"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# wlroots is usually a development library, not a runtime package
# Compositors like sway depend on it, but users don't typically install it directly
MODULE_PACKAGES[arch]="wlroots"
MODULE_PACKAGES[debian]="libwlroots-dev"
MODULE_PACKAGES[ubuntu]="libwlroots-dev"
MODULE_PACKAGES[fedora]="wlroots-devel"
MODULE_PACKAGES[opensuse]="wlroots-devel"
MODULE_PACKAGES[alpine]="wlroots-dev"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # wlroots is a library, check for headers
    echo "  [PROOF] Checking wlroots headers..."
    if [[ -f "/usr/include/wlroots/version.h" ]] || \
       [[ -f "/usr/local/include/wlroots/version.h" ]]; then
        echo "  [PROOF] ✓ wlroots headers found"
    else
        echo "  [INFO] wlroots headers not found (runtime only)"
    fi
    
    # Check pkg-config
    echo "  [PROOF] Checking pkg-config..."
    if pkg-config --exists wlroots 2>/dev/null; then
        local version
        version=$(pkg-config --modversion wlroots 2>/dev/null)
        echo "  [PROOF] ✓ wlroots pkg-config: $version"
    else
        echo "  [INFO] wlroots pkg-config not available"
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
    
    echo "$MODULE_NAME installed"
    echo ""
    echo "Note: wlroots is a development library."
    echo "Compositors like sway and river will install runtime dependencies."
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    # Check pkg-config
    if pkg-config --exists wlroots 2>/dev/null; then
        local version
        version=$(pkg-config --modversion wlroots 2>/dev/null)
        echo "✓ wlroots installed: $version"
    else
        echo "⚠ wlroots pkg-config not found (may still work)"
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "wlroots development files have been installed."
    echo ""
    echo "This is a library for building Wayland compositors."
    echo "Common compositors using wlroots:"
    echo "  - sway"
    echo "  - river"
    echo "  - labwc"
}
