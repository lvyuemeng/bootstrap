#!/bin/bash
# =============================================================================
# Module: polkit
# =============================================================================
# PolicyKit - authorization framework for unprivileged actions
# =============================================================================

MODULE_NAME="polkit"
MODULE_DESCRIPTION="Policy authentication framework"

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
    "auth:framework"
    "auth:policy"
)

# =============================================================================
# PACKAGE ADAPTATION (per distribution)
# =============================================================================

declare -A MODULE_PACKAGES

# Polkit packages
MODULE_PACKAGES[arch]="polkit polkit-gnome"
MODULE_PACKAGES[debian]="policykit-1 policykit-1-gnome"
MODULE_PACKAGES[ubuntu]="policykit-1 policykit-1-gnome"
MODULE_PACKAGES[fedora]="polkit polkit-gnome"
MODULE_PACKAGES[opensuse]="polkit polkit-gnome"
MODULE_PACKAGES[alpine]="polkit"
MODULE_PACKAGES[void]="polkit"
MODULE_PACKAGES[gentoo]="sys-auth/polkit sys-auth/polkit-gnome"

# =============================================================================
# SERVICE DEFINITION
# =============================================================================

MODULE_SERVICE_NAME="polkit"

# =============================================================================
# PROOF VERIFICATION
# =============================================================================

module_proofs() {
    echo "Running proof checks for $MODULE_NAME..."
    local result=0
    
    # Proof Level 1: Check pkexec
    echo "  [PROOF] Checking pkexec..."
    proof_command "pkexec" || result=1
    
    # Proof Level 2: Check polkitd
    echo "  [PROOF] Checking polkitd..."
    if command -v polkitd >/dev/null 2>&1; then
        echo "  [PROOF] ✓ polkitd found"
    else
        echo "  [WARN] polkitd not found"
    fi
    
    # Proof Level 3: Check polkit process
    echo "  [PROOF] Checking polkit process..."
    proof_process "polkitd" || {
        echo "  [WARN] polkitd not running"
    }
    
    # Proof Level 4: Check D-Bus
    echo "  [PROOF] Checking D-Bus..."
    proof_dbus_service "org.freedesktop.PolicyKit1" || {
        echo "  [WARN] PolicyKit D-Bus not available"
    }
    
    # Proof Level 5: Check authentication agent
    echo "  [PROOF] Checking auth agent..."
    if pgrep -x "polkit-gnome-authentication-agent" >/dev/null 2>&1; then
        echo "  [PROOF] ✓ Auth agent running"
    else
        echo "  [INFO] Auth agent not running (needs to be started in session)"
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
    pkg_install "$packages" "$distro"
    
    # Start polkit service
    start_polkit "$init"
    
    # Setup authentication agent
    setup_auth_agent
    
    echo "$MODULE_NAME installed"
}

# =============================================================================
# START POLKIT
# =============================================================================

start_polkit() {
    local init="$1"
    
    case "$init" in
        systemd)
            echo "Starting polkit via systemd..."
            sudo systemctl enable polkit 2>/dev/null || true
            sudo systemctl start polkit 2>/dev/null || true
            ;;
        openrc)
            echo "Starting polkit via OpenRC..."
            sudo rc-update add polkitd default 2>/dev/null || true
            sudo /etc/init.d/polkitd start 2>/dev/null || true
            ;;
        runit)
            echo "Starting polkit via runit..."
            sudo mkdir -p /etc/sv/polkitd
            sudo ln -sf /etc/sv/polkitd /var/service/ 2>/dev/null || true
            ;;
        *)
            echo "Trying to start polkit manually..."
            # Try to start polkitd directly
            if command -v polkitd >/dev/null 2>&1; then
                sudo polkitd &
                sleep 1
            fi
            ;;
    esac
}

# =============================================================================
# SETUP AUTHENTICATION AGENT
# =============================================================================

setup_auth_agent() {
    echo "Setting up authentication agent..."
    
    # Setup polkit-gnome agent for X11/Wayland sessions
    local agent_bin="polkit-gnome-authentication-agent-1"
    
    if ! command -v "$agent_bin" >/dev/null 2>&1; then
        echo "Warning: $agent_bin not found"
        echo "On GNOME, use gnome-polkit instead"
        return 0
    fi
    
    # Add to XDG autostart
    local autostart="${HOME}/.config/autostart/polkit-gnome.desktop"
    mkdir -p "$(dirname "$autostart")"
    
    cat > "$autostart" <<EOF
[Desktop Entry]
Type=Application
Name=PolicyKit Authentication Agent
Exec=$agent_bin
OnlyShowIn=GNOME;XFCE;LXDE;MATE;
NoDisplay=true
EOF
    
    echo "Created autostart entry for polkit-gnome-authentication-agent"
    echo "The agent will start on your next login"
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
    
    # Test pkexec
    echo ""
    echo "Testing pkexec..."
    pkexec --version 2>&1 || true
    
    # Show polkit actions
    echo ""
    echo "Listing polkit actions..."
    if command -v pkaction >/dev/null 2>&1; then
        pkaction 2>/dev/null | head -20 || true
    fi
}

# =============================================================================
# INFO
# =============================================================================

module_info() {
    cat <<EOF

$MODULE_NAME installed successfully!

Supported Distributions:
  arch, debian, ubuntu, fedora, opensuse, alpine, void, gentoo

What is Polkit?
  Polkit provides an authorization API for unprivileged
  processes to perform privileged actions. Used by:
  - Package managers (apt, pacman)
  - System settings (network, display)
  - Mount/umount drives
  - Shutdown/reboot

Usage:
  pkexec --user username command    # Run as another user
  pkaction                           # List available actions
  pkcheck --action-id org.freedesktop.login.reboot --process $$

Configuration:
  /usr/share/polkit-1/               # System actions
  /etc/polkit-1/                     # Local modifications
  /etc/polkit-1/localauthority/      # Authorization rules

Add Authorization Rules:
  # /etc/polkit-1/localauthority/50-local.d/custom.rules
  polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login.reboot") {
      return polkit.Result.YES;
    }
  });

Common Actions:
  org.freedesktop.login.reboot       # Reboot
  org.freedesktop.login.power-off    # Power off
  org.freedesktop.systemtools.backends.set-hostname  # Set hostname
  org.freedesktop.packagekit.system-upgrade         # System upgrade
  org.freedesktop.NetworkManager.enable-disable-wifi # WiFi

Troubleshooting:
  # Check auth agent is running
  ps aux | grep polkit-gnome
  
  # Check polkit is running
  systemctl status polkit
  
  # Debug
  /usr/lib/polkitd --no-debug

Proof Chain:
  Level 1: pkexec command available
  Level 2: polkitd binary found
  Level 3: polkitd process running
  Level 4: D-Bus service registered
  Level 5: Auth agent in session

EOF
}
