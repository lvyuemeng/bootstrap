#!/bin/bash
# =============================================================================
# Module: login-manager
# =============================================================================
# Login manager (Display Manager) - handles user login
# =============================================================================

MODULE_NAME="login-manager"
MODULE_DESCRIPTION="Display manager for login"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# =============================================================================
# REQUIREMENTS & PROVIDES
# =============================================================================

MODULE_REQUIRES=(
    "dbus"
)

MODULE_PROVIDES=(
    "session:login"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Login managers - user can choose one
# Default is lightdm (most universal)

# lightdm
declare -A MODULE_PACKAGES_LIGHTDM
MODULE_PACKAGES_LIGHTDM[arch]="lightdm lightdm-gtk-greeter"
MODULE_PACKAGES_LIGHTDM[debian]="lightdm lightdm-gtk-greeter"
MODULE_PACKAGES_LIGHTDM[ubuntu]="lightdm lightdm-gtk-greeter"
MODULE_PACKAGES_LIGHTDM[fedora]="lightdm lightdm-gtk-greeter"
MODULE_PACKAGES_LIGHTDM[opensuse]="lightdm lightdm-gtk-greeter2"
MODULE_PACKAGES_LIGHTDM[alpine]="lightdm"

# sddm (Qt-based)
declare -A MODULE_PACKAGES_SDDM
MODULE_PACKAGES_SDDM[arch]="sddm"
MODULE_PACKAGES_SDDM[debian]="sddm"
MODULE_PACKAGES_SDDM[ubuntu]="sddm"
MODULE_PACKAGES_SDDM[fedora]="sddm"
MODULE_PACKAGES_SDDM[opensuse]="sddm"

# gdm (GNOME)
declare -A MODULE_PACKAGES_GDM
MODULE_PACKAGES_GDM[arch]="gdm"
MODULE_PACKAGES_GDM[debian]="gdm3"
MODULE_PACKAGES_GDM[ubuntu]="gdm3"
MODULE_PACKAGES_GDM[fedora]="gdm"

# ly (minimal tty login manager)
declare -A MODULE_PACKAGES_LY
MODULE_PACKAGES_LY[arch]="ly"  # AUR

# Default to lightdm
get_packages() {
    local distro="$1"
    local manager="${BOOTSTRAP_LOGIN_MANAGER:-lightdm}"
    
    case "$manager" in
        lightdm)
            echo "${MODULE_PACKAGES_LIGHTDM[$distro]}"
            ;;
        sddm)
            echo "${MODULE_PACKAGES_SDDM[$distro]}"
            ;;
        gdm)
            echo "${MODULE_PACKAGES_GDM[$distro]}"
            ;;
        ly)
            echo "${MODULE_PACKAGES_LY[$distro]}"
            ;;
        *)
            echo "${MODULE_PACKAGES_LIGHTDM[$distro]}"
            ;;
    esac
}

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    local manager="${BOOTSTRAP_LOGIN_MANAGER:-lightdm}"
    
    echo "  Using login manager: $manager"
    
    # Proof Level 1: Check display manager
    echo "  [PROOF] Checking $manager..."
    case "$manager" in
        lightdm)
            proof_command "lightdm" || result=1
            ;;
        sddm)
            proof_command "sddm" || result=1
            ;;
        gdm)
            proof_command "gdm" || result=1
            ;;
        ly)
            proof_command "ly" || result=1
            ;;
    esac
    
    # Proof Level 2: Check service
    echo "  [PROOF] Checking service..."
    case "$manager" in
        lightdm)
            proof_service_active "lightdm" || result=1
            ;;
        sddm)
            proof_service_active "sddm" || result=1
            ;;
        gdm)
            proof_service_active "gdm" || result=1
            ;;
    esac
    
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
    
    local manager="${BOOTSTRAP_LOGIN_MANAGER:-lightdm}"
    echo "Login manager: $manager"
    
    # Get packages
    local packages
    packages=$(get_packages "$distro")
    
    if [[ -z "$packages" ]]; then
        echo "Error: No packages defined for distro: $distro with manager: $manager"
        return 1
    fi
    
    echo "Installing packages: $packages"
    pkg_install "$packages"
    
    # Enable service
    case "$init" in
        systemd)
            echo "Enabling login manager service..."
            case "$manager" in
                lightdm)
                    svc_enable "lightdm" 2>/dev/null || true
                    svc_start "lightdm" 2>/dev/null || true
                    ;;
                sddm)
                    svc_enable "sddm" 2>/dev/null || true
                    svc_start "sddm" 2>/dev/null || true
                    ;;
                gdm)
                    svc_enable "gdm" 2>/dev/null || true
                    svc_start "gdm" 2>/dev/null || true
                    ;;
            esac
            ;;
    esac
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    local manager="${BOOTSTRAP_LOGIN_MANAGER:-lightdm}"
    
    case "$manager" in
        lightdm)
            if proof_command "lightdm"; then
                echo "✓ lightdm installed"
            else
                echo "✗ lightdm not found"
                return 1
            fi
            ;;
        sddm)
            if proof_command "sddm"; then
                echo "✓ sddm installed"
            else
                echo "✗ sddm not found"
                return 1
            fi
            ;;
        gdm)
            if proof_command "gdm"; then
                echo "✓ gdm installed"
            else
                echo "✗ gdm not found"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "Login manager has been installed."
    echo ""
    echo "To change login manager, set BOOTSTRAP_LOGIN_MANAGER:"
    echo "  export BOOTSTRAP_LOGIN_MANAGER=sddm"
    echo "  export BOOTSTRAP_LOGIN_MANAGER=gdm"
    echo ""
    echo "Supported managers:"
    echo "  lightdm (default) - Universal, GTK"
    echo "  sddm             - Qt-based"
    echo "  gdm              - GNOME"
}
