#!/bin/bash
# =============================================================================
# Module: gpu-intel
# =============================================================================
# Intel GPU drivers
# =============================================================================

MODULE_NAME="gpu-intel"
MODULE_DESCRIPTION="Intel GPU drivers"

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
    "hardware:gpu"
    "display:acceleration"
)

# =============================================================================
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

# Intel GPU packages - keyed by package manager
MODULE_PACKAGES[pacman]="mesa intel-media-driver libva-intel-driver"
MODULE_PACKAGES[apt]="xserver-xorg-video-intel mesa-vulkan-drivers intel-media-va-driver"
MODULE_PACKAGES[dnf]="mesa-dri-drivers mesa-vulkan-drivers intel-media-driver"
MODULE_PACKAGES[zypper]="mesa-dri-drivers Mesa-libGL1 intel-media-driver"
MODULE_PACKAGES[apk]="mesa mesa-intel driver libva-intel-driver"
MODULE_PACKAGES[xbps]="mesa intel-ucode"
MODULE_PACKAGES[emerge]="media-libs/mesa x11-drivers/xf86-video-intel"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check Intel GPU
    echo "  [PROOF] Checking for Intel GPU..."
    if lspci 2>/dev/null | grep -qi "vga.*intel"; then
        echo "  [PROOF] ✓ Intel GPU detected"
    else
        echo "  [PROOF] ! No Intel GPU detected"
    fi
    
    # Proof Level 2: Check DRM module
    echo "  [PROOF] Checking i915 module..."
    proof_kernel_module "i915" || result=1
    
    # Proof Level 3: Check Vulkan
    echo "  [PROOF] Checking Vulkan..."
    if command -v vulkaninfo >/dev/null 2>&1; then
        if vulkaninfo 2>/dev/null | grep -qi "intel"; then
            echo "  [PROOF] ✓ Intel Vulkan available"
        fi
    fi
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    local init
    init=$(init_detect)
    
    echo "Detected: pkgmgr=$pkgmgr, init=$init"
    
    # Get packages for this pkgmgr
    local packages="${MODULE_PACKAGES[$pkgmgr]}"
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for pkgmgr: $pkgmgr"
        echo "Supported pkgmgrs: ${!MODULE_PACKAGES[*]}"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages" "$pkgmgr"
    
    # Load i915 module
    echo "Loading i915 module..."
    modprobe i915 2>/dev/null || true
    
    # Enable early KMS
    enable_early_kms
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# ENABLE EARLY KMS
# =============================================================================

enable_early_kms() {
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    
    case "$pkgmgr" in
        pacman)
            # Add i915 to mkinitcpio.conf
            if [[ -f "/etc/mkinitcpio.conf" ]]; then
                if ! grep -q "i915" /etc/mkinitcpio.conf; then
                    echo "Adding i915 to mkinitcpio.conf..."
                    sed -i 's/MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf
                    mkinitcpio -P 2>/dev/null || true
                fi
            fi
            ;;
        apt)
            # Add i915 to initramfs
            echo "i915" | tee /etc/initramfs-tools/modules >/dev/null 2>&1 || true
            update-initramfs -u 2>/dev/null || true
            ;;
    esac
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    # Check i915 module
    if proof_kernel_module "i915"; then
        echo "✓ i915 module loaded"
    else
        echo "⚠ i915 module not loaded"
    fi
    
    # Check /dev/dri
    if [[ -e "/dev/dri/card0" ]]; then
        echo "✓ GPU device node exists"
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "Intel GPU drivers have been installed."
    echo ""
    echo "Features enabled:"
    echo "  - OpenGL (Mesa)"
    echo "  - Vulkan"
    echo "  - VA-API (video acceleration)"
    echo ""
    echo "Key commands:"
    echo "  vulkaninfo          # Check Vulkan support"
    echo "  glxinfo             # Check OpenGL info"
    echo "  intel_gpu_top       # GPU usage monitor"
}
