#!/bin/bash
# =============================================================================
# Module: network-manager
# =============================================================================
# NetworkManager with full distro/init system adaptation
# Uses distro.sh library for package/service management
# =============================================================================

MODULE_NAME="network-manager"
MODULE_DESCRIPTION="Network connection management"

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
    "init"
)

MODULE_PROVIDES=(
    "network:manager"
    "network:dhcp"
    "network:wifi"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Arch Linux
MODULE_PACKAGES[arch]="networkmanager"

# Debian/Ubuntu
MODULE_PACKAGES[debian]="network-manager"
MODULE_PACKAGES[ubuntu]="network-manager"

# Alpine Linux
MODULE_PACKAGES[alpine]="NetworkManager"

# Void Linux
MODULE_PACKAGES[void]="NetworkManager"

# Gentoo
MODULE_PACKAGES[gentoo]="net-misc/networkmanager"

# Fedora/RHEL
MODULE_PACKAGES[fedora]="NetworkManager"

# openSUSE
MODULE_PACKAGES[opensuse]="NetworkManager"

# =============================================================================
# SERVICE DEFINITION
# =============================================================================

MODULE_SERVICE_NAME="NetworkManager"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Service active
    echo "  [PROOF] Checking service active..."
    proof_service_active "NetworkManager" || {
        echo "  [WARN] NetworkManager service not active"
        result=1
    }
    
    # Proof Level 2: Process running
    echo "  [PROOF] Checking process..."
    proof_process "NetworkManager" || {
        echo "  [WARN] NetworkManager process not running"
        result=1
    }
    
    # Proof Level 3: Functionality
    echo "  [PROOF] Checking nmcli..."
    proof_command "nmcli" || result=1
    
    # Proof Level 4: Network interfaces
    echo "  [PROOF] Checking network..."
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli device status 2>/dev/null | grep -q "connected"; then
            echo "  [PROOF] ✓ Network connected"
        else
            echo "  [PROOF] No active connections (may be expected)"
        fi
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
    
    # Install packages using distro.sh library
    pkg_install "$packages" "$distro"
    
    # Enable and start service using distro.sh library
    svc_enable "$MODULE_SERVICE_NAME" "$init"
    svc_start "$MODULE_SERVICE_NAME" "$init"
    
    # Configure
    local config_file="/etc/NetworkManager/NetworkManager.conf"
    if [[ ! -f "$config_file" ]]; then
        mkdir -p "$(dirname "$config_file")"
        
        # Create basic config
        cat > "$config_file" <<'EOF'
[main]
plugins=ifupdown

[connection]
wifi.powersave=2

[device]
wifi.scan-rand-mac-address=no

[logging]
level=INFO
domains=PLATFORM,RFKILL,WIFI
EOF
    fi
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# VERIFY
# =============================================================================

module_verify() {
    echo "Verifying $MODULE_NAME installation..."
    
    local distro
    distro=$(distro_detect)
    local init
    init=$(init_detect)
    
    echo "Running on: distro=$distro, init=$init"
    
    # Run proofs
    module_proofs
    
    # Check service status using distro.sh library
    echo ""
    echo "Service status:"
    svc_status "$MODULE_SERVICE_NAME" "$init"
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, alpine, void, gentoo, fedora, opensuse

Supported Init Systems:
  systemd, openrc, runit, sysvinit

Usage:
  nmcli device status        # Show network devices
  nmcli connection show      # Show connections
  nmcli device wifi list     # Show WiFi networks
  nmcli device wifi connect SSID password PASSWORD

Configuration:
  /etc/NetworkManager/NetworkManager.conf

Service Management:
  Uses svc_enable/svc_start from distro.sh library

Proof Chain:
  Level 1: Service active
  Level 2: Process running  
  Level 3: nmcli command available
  Level 4: Network connectivity

EOF
}
