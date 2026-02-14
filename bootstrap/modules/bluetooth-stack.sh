#!/bin/bash
# =============================================================================
# Module: bluetooth-stack
# =============================================================================
# BlueZ Bluetooth stack with proof-first verification
# Demonstrates dependency chain: kernel -> dbus -> service -> audio
# =============================================================================

MODULE_NAME="bluetooth-stack"
MODULE_DESCRIPTION="BlueZ Bluetooth stack"

# Load bootstrap libraries
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"

# === REQUIREMENTS (Dependencies) ===
MODULE_REQUIRES=(
    "dbus"
    "kernel:btusb"
)

# === OPTIONAL ===
MODULE_OPTIONAL=(
    "audio-pipewire"    # For Bluetooth A2DP
)

# === PROVIDES ===
MODULE_PROVIDES=(
    "bluetooth:bluetoothd"
    "bluetooth:rfkill"
)

# === PACKAGES (Distribution-specific) ===
declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="bluez bluez-utils"
MODULE_PACKAGES[debian]="bluez bluetooth"
MODULE_PACKAGES[alpine]="bluez bluez-openrc"
MODULE_PACKAGES[gentoo]="net-wireless/bluez"
MODULE_PACKAGES[void]="bluez"

# =============================================================================
# PROOF VERIFICATION (Bottom-to-Top)
# =============================================================================

# Level 0: Kernel Prerequisites
proof_kernel_level() {
    echo "=== PROOF Level 0: Kernel Prerequisites ==="
    local result=0
    
    # Check kernel module
    proof_kernel_module "btusb" || {
        echo "  Loading btusb module..."
        modprobe btusb 2>/dev/null || result=1
    }
    
    # Check rfkill (may be built-in or module)
    proof_command "rfkill" || echo "  Warning: rfkill not found"
    
    return $result
}

# Level 1: System Services
proof_service_level() {
    echo "=== PROOF Level 1: System Services ==="
    local result=0
    
    # Check D-Bus (prerequisite)
    proof_process "dbus-daemon" || {
        echo "  Error: D-Bus not running"
        return 1
    }
    
    # Check bluetooth service
    proof_service_active "bluetooth" || result=1
    
    return $result
}

# Level 2: Daemon Running
proof_daemon_level() {
    echo "=== PROOF Level 2: Daemon Running ==="
    local result=0
    
    # Check bluetoothd process
    proof_process "bluetoothd" || result=1
    
    # Check D-Bus registration
    proof_dbus_service "org.bluez" || result=1
    
    return $result
}

# Level 3: Hardware/Controller
proof_hardware_level() {
    echo "=== PROOF Level 3: Hardware ==="
    local result=0
    
    # Check for Bluetooth adapters
    if command -v bluetoothctl >/dev/null 2>&1; then
        if bluetoothctl list 2>/dev/null | grep -q "Controller"; then
            echo "  [PROOF] ✓ Bluetooth controller detected"
        else
            echo "  [PROOF] No Bluetooth controller found"
            result=$PROOF_SKIP  # May be expected on some systems
        fi
    fi
    
    return $result
}

# Combined proof chain (bottom-to-top)
module_proofs() {
    echo "Running bottom-to-top proof chain for $MODULE_NAME..."
    local result=0
    
    # Level 0: Kernel
    echo ""
    proof_kernel_level || result=1
    
    # Level 1: Services
    echo ""
    proof_service_level || result=1
    
    # Level 2: Daemon
    echo ""
    proof_daemon_level || result=1
    
    # Level 3: Hardware
    echo ""
    proof_hardware_level || {
        # Don't fail on missing hardware
        echo "  Note: Hardware check non-fatal"
    }
    
    return $result
}

# =============================================================================
# INSTALL
# =============================================================================

module_install() {
    echo "Installing $MODULE_NAME..."
    
    # Detect distribution
    local distro
    if [[ -f /etc/os-release ]]; then
        distro=$(source /etc/os-release && echo "$ID")
    fi
    
    # Install packages (would be done by package manager in real bootstrap)
    local packages="${MODULE_PACKAGES[$distro]:-bluez}"
    echo "  Would install: $packages"
    
    # Load kernel module
    if ! lsmod | grep -q "^btusb "; then
        modprobe btusb
    fi
    
    # Enable and start service
    systemctl enable bluetooth 2>/dev/null || true
    systemctl start bluetooth 2>/dev/null || true
    
    # Configure (using template)
    config_set_placeholder "BLUETOOTH_AUTO_ENABLE" "true"
    config_set_placeholder "BLUETOOTH_DEBUG" "false"
    config_set_placeholder "BLUETOOTH_REMEMBER_POWERED" "true"
    
    local config_file="/etc/bluetooth/main.conf"
    if [[ ! -f "$config_file" ]] || [[ ! -s "$config_file" ]]; then
        config_render_template "bluetooth/main.conf" "$config_file"
    fi
    
    # Ensure user in bluetooth group
    if ! groups "$TARGET_USER" | grep -qw "bluetooth"; then
        echo "  Adding user to bluetooth group: usermod -aG bluetooth $TARGET_USER"
    fi
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME installation..."
    module_proofs
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Usage:
  bluetoothctl           # Interactive control
  
  # In bluetoothctl:
  > power on
  > agent on
  > default-agent
  > scan on
  > pair XX:XX:XX:XX:XX:XX
  > connect XX:XX:XX:XX:XX:XX

Commands:
  rfkill list bluetooth  # Check if blocked
  hciconfig -a           # Show adapter info

Configuration:
  /etc/bluetooth/main.conf

Proof Chain:
  Level 0: Kernel (btusb module)
  Level 1: Services (dbus, bluetooth service)
  Level 2: Daemon (bluetoothd running, D-Bus registered)
  Level 3: Hardware (controller detected)

EOF
}
