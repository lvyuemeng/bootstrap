#!/bin/bash
# =============================================================================
# Module: dbus
# =============================================================================
# D-Bus system/message bus - inter-process communication
# =============================================================================

MODULE_NAME="dbus"
MODULE_DESCRIPTION="D-Bus system/message bus"

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
    "system:bus"
    "system:ipc"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# D-Bus packages
MODULE_PACKAGES[arch]="dbus"
MODULE_PACKAGES[debian]="dbus"
MODULE_PACKAGES[ubuntu]="dbus"
MODULE_PACKAGES[fedora]="dbus"
MODULE_PACKAGES[opensuse]="dbus"
MODULE_PACKAGES[alpine]="dbus"
MODULE_PACKAGES[void]="dbus"
MODULE_PACKAGES[gentoo]="sys-apps/dbus"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check dbus-daemon
    echo "  [PROOF] Checking dbus-daemon..."
    proof_command "dbus-daemon" || result=1
    
    # Proof Level 2: Check dbus-send
    echo "  [PROOF] Checking dbus-send..."
    proof_command "dbus-send" || result=1
    
    # Proof Level 3: Check dbus-monitor
    echo "  [PROOF] Checking dbus-monitor..."
    proof_command "dbus-monitor" || result=1
    
    # Proof Level 4: Check dbus service
    echo "  [PROOF] Checking dbus service..."
    if proof_service_active "dbus"; then
        echo "  [PROOF] ✓ dbus service is active"
    else
        echo "  [PROOF] ! dbus service not active (may be socket-activated)"
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
    
    # Enable and start dbus service
    case "$init" in
        systemd)
            echo "Enabling dbus service..."
            svc_enable "dbus" 2>/dev/null || true
            svc_start "dbus" 2>/dev/null || true
            ;;
        openrc|runits)
            echo "D-Bus typically started by init system"
            ;;
    esac
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME..."
    
    # Check dbus-daemon is running
    if proof_process "dbus-daemon"; then
        echo "✓ dbus-daemon is running"
    else
        echo "✗ dbus-daemon is not running"
        return 1
    fi
    
    # Test dbus-send
    if dbus-send --system --dest=org.freedesktop.DBus --type=method_call \
        --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
        echo "✓ D-Bus system bus is functional"
    else
        echo "✗ D-Bus system bus not functional"
        return 1
    fi
    
    return 0
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    echo "D-Bus has been installed."
    echo ""
    echo "Key commands:"
    echo "  dbus-send        # Send message to D-Bus"
    echo "  dbus-monitor     # Monitor D-Bus messages"
    echo "  dbus-launch      # Start D-Bus session"
    echo ""
    echo "Configuration:"
    echo "  /etc/dbus-1/    # System D-Bus config"
    echo "  ~/.dbus/        # Session D-Bus keys"
}
