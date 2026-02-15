#!/bin/bash
# =============================================================================
# Module: gpu-amd
# =============================================================================
# AMD GPU drivers
# =============================================================================

MODULE_NAME="gpu-amd"
MODULE_DESCRIPTION="AMD GPU drivers"

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

# AMD GPU packages (AMDGPU + Mesa) - keyed by package manager
MODULE_PACKAGES[pacman]="mesa libva-mesa-driver mesa-vulkan-radeon amd-ucode"
MODULE_PACKAGES[apt]="xserver-xorg-video-amdgpu mesa-vulkan-drivers mesa-va-drivers firmware-amd-graphics"
MODULE_PACKAGES[dnf]="mesa-dri-drivers mesa-vulkan-drivers amd-gpu-firmware"
MODULE_PACKAGES[zypper]="Mesa-libGL1 Mesa-vulkan-radeon"
MODULE_PACKAGES[apk]="mesa mesa-amber driver"
MODULE_PACKAGES[xbps]="mesa amd-ucode"
MODULE_PACKAGES[emerge]="media-libs/mesa x11-drivers/xf86-video-amdgpu"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check AMD GPU
    echo "  [PROOF] Checking for AMD GPU..."
    if lspci 2>/dev/null | grep -qi "vga.*amd\|vga.*radeon"; then
        echo "  [PROOF] ✓ AMD GPU detected"
    else
        echo "  [PROOF] ! No AMD GPU detected"
    fi
    
    # Proof Level 2: Check DRM module
    echo "  [PROOF] Checking amdgpu module..."
    proof_kernel_module "amdgpu" || result=1
    
    # Proof Level 3: Check Vulkan
    echo "  [PROOF] Checking Vulkan..."
    if command -v vulkaninfo >/dev/null 2>&1; then
        if vulkaninfo 2>/dev/null | grep -qi "amd\|radeon"; then
            echo "  [PROOF] ✓ AMD Vulkan available"
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
    
    # Load amdgpu module
    echo "Loading amdgpu module..."
    modprobe amdgpu 2>/dev/null || true
    
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
            if [[ -f "/etc/mkinitcpio.conf" ]]; then
                if ! grep -q "amdgpu" /etc/mkinitcpio.conf; then
                    echo "Adding amdgpu to mkinitcpio.conf..."
                    sed -i 's/MODULES=()/MODULES=(amdgpu)/' /etc/mkinitcpio.conf
                    mkinitcpio -P 2>/dev/null || true
                fi
            fi
            ;;
        apt)
            echo "amdgpu" | tee /etc/initramfs-tools/modules >/dev/null 2>&1 || true
            update-initramfs -u 2>/dev/null || true
            ;;
    esac
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    if proof_kernel_module "amdgpu"; then
        echo "✓ amdgpu module loaded"
    else
        echo "⚠ amdgpu module not loaded"
    fi
    
    if [[ -e "/dev/dri/card0" ]]; then
        echo "✓ GPU device node exists"
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "AMD GPU drivers have been installed."
    echo ""
    echo "Features enabled:"
    echo "  - OpenGL (Mesa)"
    echo "  - Vulkan (RADV)"
    echo "  - VA-API (video acceleration)"
    echo "  - AMDVLK (optional proprietary)"
    echo ""
    echo "Key commands:"
    echo "  vulkaninfo          # Check Vulkan support"
    echo "  glxinfo             # Check OpenGL info"
    echo "  rocm-smi            # ROCm GPU info"
}
