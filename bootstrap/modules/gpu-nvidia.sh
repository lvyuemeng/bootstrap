#!/bin/bash
# =============================================================================
# Module: gpu-nvidia
# =============================================================================
# NVIDIA GPU drivers
# =============================================================================

MODULE_NAME="gpu-nvidia"
MODULE_DESCRIPTION="NVIDIA GPU drivers"

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
    "hardware:cuda"
)

# =============================================================================
# PACKAGE ADAPTATION (per package manager)
# =============================================================================

declare -A MODULE_PACKAGES

# NVIDIA packages - different options
# Open source: nouveau (not recommended for gaming)
# Proprietary: nvidia

# NVIDIA proprietary driver - keyed by package manager
MODULE_PACKAGES[pacman]="nvidia nvidia-utils nvidia-settings"
MODULE_PACKAGES[apt]="nvidia-driver libnvidia-gl-*.so.* nvidia-settings"
MODULE_PACKAGES[dnf]="akmod-nvidia xorg-x11-drv-nvidia-cuda"
MODULE_PACKAGES[zypper]="nvidia-driver-G06"
MODULE_PACKAGES[apk]="nvidia nvidia-utils"
MODULE_PACKAGES[xbps]="nvidia"
MODULE_PACKAGES[emerge]="x11-drivers/nvidia-drivers"

# Nouveau (open source - not recommended)
declare -A MODULE_PACKAGES_NOUVEAU
MODULE_PACKAGES_NOUVEAU[pacman]="mesa xf86-video-nouveau"
MODULE_PACKAGES_NOUVEAU[apt]="xserver-xorg-video-nouveau"

# =============================================================================

get_packages() {
    local pkgmgr="$1"
    local driver="${BOOTSTRAP_NVIDIA_DRIVER:-nvidia}"
    
    if [[ "$driver" == "nouveau" ]]; then
        echo "${MODULE_PACKAGES_NOUVEAU[$pkgmgr]}"
    else
        echo "${MODULE_PACKAGES[$pkgmgr]}"
    fi
}

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    local driver="${BOOTSTRAP_NVIDIA_DRIVER:-nvidia}"
    
    echo "  Using driver: $driver"
    
    # Proof Level 1: Check NVIDIA GPU
    echo "  [PROOF] Checking for NVIDIA GPU..."
    if lspci 2>/dev/null | grep -qi "vga.*nvidia"; then
        echo "  [PROOF] ✓ NVIDIA GPU detected"
    else
        echo "  [PROOF] ! No NVIDIA GPU detected"
    fi
    
    # Proof Level 2: Check driver
    echo "  [PROOF] Checking $driver module..."
    case "$driver" in
        nvidia)
            proof_kernel_module "nvidia" || result=1
            ;;
        nouveau)
            proof_kernel_module "nouveau" || result=1
            ;;
    esac
    
    # Proof Level 3: Check nvidia-smi
    if [[ "$driver" == "nvidia" ]]; then
        echo "  [PROOF] Checking nvidia-smi..."
        proof_command "nvidia-smi" || result=1
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
    local driver="${BOOTSTRAP_NVIDIA_DRIVER:-nvidia}"
    
    echo "Detected: pkgmgr=$pkgmgr, init=$init"
    echo "Driver: $driver"
    
    # Get packages
    local packages
    packages=$(get_packages "$pkgmgr")
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for pkgmgr: $pkgmgr"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages" "$pkgmgr"
    
    # Load driver
    echo "Loading $driver module..."
    case "$driver" in
        nvidia)
            modprobe nvidia 2>/dev/null || true
            # Generate module deps
            depmod -a 2>/dev/null || true
            ;;
        nouveau)
            modprobe nouveau 2>/dev/null || true
            ;;
    esac
    
    # Enable driver
    enable_driver
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# ENABLE DRIVER
# =============================================================================

enable_driver() {
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || { echo "ERROR: Cannot detect package manager"; return 1; }
    local driver="${BOOTSTRAP_NVIDIA_DRIVER:-nvidia}"
    
    case "$pkgmgr" in
        pacman)
            if [[ "$driver" == "nvidia" ]] && [[ -f "/etc/mkinitcpio.conf" ]]; then
                if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
                    echo "Adding nvidia to mkinitcpio.conf..."
                    sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm)/' /etc/mkinitcpio.conf
                    mkinitcpio -P 2>/dev/null || true
                fi
            fi
            ;;
    esac
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    local driver="${BOOTSTRAP_NVIDIA_DRIVER:-nvidia}"
    
    case "$driver" in
        nvidia)
            if proof_kernel_module "nvidia"; then
                echo "✓ nvidia module loaded"
            else
                echo "⚠ nvidia module not loaded"
            fi
            
            if proof_command "nvidia-smi"; then
                nvidia-smi --query-gpu=name,driver_version --format=csv 2>/dev/null || true
            fi
            ;;
        nouveau)
            if proof_kernel_module "nouveau"; then
                echo "✓ nouveau module loaded"
            else
                echo "⚠ nouveau module not loaded"
            fi
            ;;
    esac
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "NVIDIA GPU drivers have been installed."
    echo ""
    echo "Note: For open source driver, use: export BOOTSTRAP_NVIDIA_DRIVER=nouveau"
    echo ""
    echo "Features enabled:"
    echo "  - OpenGL"
    echo "  - Vulkan"
    echo "  - CUDA (if installed)"
    echo "  - NVENC (video encoding)"
    echo ""
    echo "Key commands:"
    echo "  nvidia-smi          # GPU status and management"
    echo "  nvidia-settings    # GUI settings"
}
