#!/bin/bash
# =============================================================================
# Distribution & Service Management Library
# =============================================================================
# Provides cross-distribution package installation and init system service management
# =============================================================================

# Load logging
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${BOOTSTRAP_DIR}/lib/log.sh"

# =============================================================================
# DISTRIBUTION DETECTION
# =============================================================================

# Detect the current Linux distribution
# Usage: local distro=$(distro_detect)
distro_detect() {
    local distro=""
    
    # Primary method: /etc/os-release
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="$ID"
        
        # Handle derivatives (e.g., linuxmint -> ubuntu)
        case "$ID" in
            linuxmint|pop|zorin) distro="debian" ;;
            antergos|manjaro|endeavouros) distro="arch" ;;
        esac
    fi
    
    # Fallback methods for older systems
    if [[ -z "$distro" ]]; then
        if [[ -f /etc/alpine-release ]]; then
            distro="alpine"
        elif [[ -f /etc/void-release ]]; then
            distro="void"
        elif [[ -f /etc/gentoo-release ]]; then
            distro="gentoo"
        elif [[ -f /etc/redhat-release ]]; then
            distro="fedora"
        elif [[ -f /etc/debian_version ]]; then
            distro="debian"
        fi
    fi
    
    echo "${distro:-unknown}"
}

# Get distribution name (full)
# Usage: local name=$(distro_name)
distro_name() {
    local name=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        name="$NAME"
    elif [[ -f /etc/alpine-release ]]; then
        name="Alpine Linux"
    elif [[ -f /etc/void-release ]]; then
        name="Void Linux"
    elif [[ -f /etc/gentoo-release ]]; then
        name="Gentoo"
    fi
    
    echo "${name:-Unknown Linux}"
}

# =============================================================================
# INIT SYSTEM DETECTION
# =============================================================================

# Detect the init system
# Usage: local init=$(init_detect)
init_detect() {
    local init=""
    
    # Check for systemd
    if [[ -d /run/systemd/system ]] || pidof systemd >/dev/null 2>&1; then
        init="systemd"
    # Check for OpenRC
    elif [[ -f /sbin/openrc ]]; then
        init="openrc"
    # Check for runit
    elif [[ -f /sbin/runit ]] || [[ -d /etc/runit ]]; then
        init="runit"
    # Check for s6
    elif [[ -f /bin/s6-rc ]]; then
        init="s6"
    # Check for sysvinit
    elif [[ -f /etc/init.d/rc ]]; then
        init="sysvinit"
    fi
    
    echo "${init:-unknown}"
}

# =============================================================================
# PACKAGE MANAGER DETECTION
# =============================================================================

# Detect the package manager directly
# Usage: local pkgmgr=$(pkgmgr_detect)
pkgmgr_detect() {
    local pkgmgr=""
    
    # Check for package manager commands (in order of preference)
    # Allow manual override via environment variable
    if [[ -n "$BOOTSTRAP_PKGMGR" ]]; then
        pkgmgr="$BOOTSTRAP_PKGMGR"
    elif command -v pacman >/dev/null 2>&1; then
        pkgmgr="pacman"
    elif command -v apt >/dev/null 2>&1; then
        pkgmgr="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pkgmgr="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        pkgmgr="zypper"
    elif command -v apk >/dev/null 2>&1; then
        pkgmgr="apk"
    elif command -v xbps-install >/dev/null 2>&1; then
        pkgmgr="xbps"
    elif command -v emerge >/dev/null 2>&1; then
        pkgmgr="emerge"
    fi
    
    if [[ -z "$pkgmgr" ]]; then
        log_error "Cannot detect package manager"
        return 1
    fi
    
    echo "$pkgmgr"
}

# Get package manager name (human-readable)
# Usage: local name=$(pkgmgr_name [pkgmgr])
pkgmgr_name() {
    local pkgmgr="${1:-$(pkgmgr_detect)}"
    
    case "$pkgmgr" in
        apt)        echo "APT" ;;
        pacman)     echo "Pacman" ;;
        dnf)        echo "DNF" ;;
        zypper)     echo "Zypper" ;;
        apk)        echo "APK" ;;
        xbps)       echo "XBPS" ;;
        emerge)     echo "Portage" ;;
        *)          echo "Unknown" ;;
    esac
}

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

# Install packages (package-manager-aware)
# Usage: pkg_install "package1 package2" [pkgmgr]
pkg_install() {
    local packages="$1"
    local pkgmgr="${2:-$(pkgmgr_detect)}"
    
    if [[ -z "$packages" ]]; then
        log_debug "No packages to install"
        return 0
    fi
    
    if [[ -z "$pkgmgr" ]]; then
        log_error "Cannot detect package manager"
        return 1
    fi
    
    log_info "Installing packages: $packages (pkgmgr: $pkgmgr)"
    
    case "$pkgmgr" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt update -qq && apt install -y -qq $packages
            ;;
        pacman)
            pacman -S --noconfirm $packages
            ;;
        dnf)
            dnf install -y $packages
            ;;
        zypper)
            zypper install -y --no-confirm $packages
            ;;
        apk)
            apk add $packages
            ;;
        xbps)
            xbps-install -y $packages
            ;;
        emerge)
            emerge --ask --noreplace $packages
            ;;
        *)
            log_error "Unknown package manager: $pkgmgr"
            log_error "Please install manually: $packages"
            return 1
            ;;
    esac
}

# Remove packages
# Usage: pkg_remove "package1 package2" [pkgmgr]
pkg_remove() {
    local packages="$1"
    local pkgmgr="${2:-$(pkgmgr_detect)}"
    
    if [[ -z "$pkgmgr" ]]; then
        log_error "Cannot detect package manager"
        return 1
    fi
    
    log_info "Removing packages: $packages (pkgmgr: $pkgmgr)"
    
    case "$pkgmgr" in
        apt)
            apt remove -y $packages
            ;;
        pacman)
            pacman -R --noconfirm $packages
            ;;
        dnf)
            dnf remove -y $packages
            ;;
        zypper)
            zypper remove -y $packages
            ;;
        apk)
            apk del $packages
            ;;
        xbps)
            xbps-remove -y $packages
            ;;
        emerge)
            emerge --deselect $packages
            ;;
        *)
            log_error "Unknown package manager: $pkgmgr"
            return 1
            ;;
    esac
}

# Search for package
# Usage: pkg_search "package-name" [pkgmgr]
pkg_search() {
    local pattern="$1"
    local pkgmgr="${2:-$(pkgmgr_detect)}"
    
    if [[ -z "$pkgmgr" ]]; then
        echo "ERROR: Cannot detect package manager"
        return 1
    fi
    
    case "$pkgmgr" in
        apt)
            apt search "$pattern"
            ;;
        pacman)
            pacman -Ss "$pattern"
            ;;
        dnf)
            dnf search "$pattern"
            ;;
        zypper)
            zypper search "$pattern"
            ;;
        apk)
            apk search "$pattern"
            ;;
        xbps)
            xbps-query -Rs "$pattern"
            ;;
        emerge)
            emerge --search "$pattern"
            ;;
    esac
}

# Check if package is installed
# Usage: pkg_installed "package" [pkgmgr]
pkg_installed() {
    local package="$1"
    local pkgmgr="${2:-$(pkgmgr_detect)}"
    
    if [[ -z "$pkgmgr" ]]; then
        echo "ERROR: Cannot detect package manager"
        return 1
    fi
    
    case "$pkgmgr" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        dnf)
            rpm -q "$package" &>/dev/null
            ;;
        zypper)
            rpm -q "$package" &>/dev/null
            ;;
        apk)
            apk info "$package" &>/dev/null
            ;;
        xbps)
            xbps-query -e "$package" &>/dev/null
            ;;
        emerge)
            qlist "$package" &>/dev/null
            ;;
    esac
}

# =============================================================================
# SERVICE MANAGEMENT (Init-Aware)
# =============================================================================

# Enable service at boot
# Usage: svc_enable "servicename" [init]
svc_enable() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    log_info "Enabling service: $service (init: $init)"
    
    case "$init" in
        systemd)
            systemctl enable "$service"
            ;;
        openrc)
            rc-update add "$service" default 2>/dev/null || true
            ;;
        runit)
            ln -sf "/etc/sv/$service" "/var/service/" 2>/dev/null || true
            ;;
        s6)
            # s6 uses symlinks in /service
            ln -sf "/etc/s6/$service" "/service/" 2>/dev/null || true
            ;;
        sysvinit)
            update-rc.d "$service" defaults 2>/dev/null || true
            ;;
        *)
            log_error "Unknown init system: $init"
            return 1
            ;;
    esac
}

# Start service
# Usage: svc_start "servicename" [init]
svc_start() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    log_info "Starting service: $service (init: $init)"
    
    case "$init" in
        systemd)
            systemctl start "$service"
            ;;
        openrc)
            rc-service "$service" start 2>/dev/null || /etc/init.d/"$service" start 2>/dev/null || true
            ;;
        runit)
            sv up "$service" 2>/dev/null || true
            ;;
        s6)
            s6-svc -u "/service/$service" 2>/dev/null || true
            ;;
        sysvinit)
            /etc/init.d/"$service" start 2>/dev/null || true
            ;;
    esac
}

# Stop service
# Usage: svc_stop "servicename" [init]
svc_stop() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    log_info "Stopping service: $service (init: $init)"
    
    case "$init" in
        systemd)
            systemctl stop "$service"
            ;;
        openrc)
            rc-service "$service" stop 2>/dev/null || /etc/init.d/"$service" stop 2>/dev/null || true
            ;;
        runit)
            sv down "$service" 2>/dev/null || true
            ;;
        s6)
            s6-svc -d "/service/$service" 2>/dev/null || true
            ;;
        sysvinit)
            /etc/init.d/"$service" stop 2>/dev/null || true
            ;;
    esac
}

# Restart service
# Usage: svc_restart "servicename" [init]
svc_restart() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    log_info "Restarting service: $service (init: $init)"
    
    case "$init" in
        systemd)
            systemctl restart "$service"
            ;;
        openrc)
            rc-service "$service" restart 2>/dev/null || /etc/init.d/"$service" restart 2>/dev/null || true
            ;;
        runit)
            sv restart "$service" 2>/dev/null || true
            ;;
        s6)
            s6-svc -t "/service/$service" 2>/dev/null || true
            ;;
        sysvinit)
            /etc/init.d/"$service" restart 2>/dev/null || true
            ;;
    esac
}

# Check service status
# Usage: svc_status "servicename" [init]
svc_status() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    case "$init" in
        systemd)
            systemctl status "$service"
            ;;
        openrc)
            rc-service "$service" status
            ;;
        runit)
            sv status "$service" 2>/dev/null || echo "Service $service status unknown"
            ;;
        s6)
            s6-svc status "/service/$service" 2>/dev/null || echo "Service $service status unknown"
            ;;
    esac
}

# Check if service is enabled
# Usage: svc_is_enabled "servicename" [init]
svc_is_enabled() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    case "$init" in
        systemd)
            systemctl is-enabled "$service" &>/dev/null
            ;;
        openrc)
            rc-status --list 2>/dev/null | grep -q "$service"
            ;;
        runit)
            [[ -L "/var/service/$service" ]]
            ;;
        s6)
            [[ -L "/service/$service" ]]
            ;;
    esac
}

# Check if service is active/running
# Usage: svc_is_active "servicename" [init]
svc_is_active() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    case "$init" in
        systemd)
            systemctl is-active "$service" &>/dev/null
            ;;
        openrc)
            rc-service "$service" status 2>/dev/null | grep -q "started"
            ;;
        runit)
            sv status "$service" 2>/dev/null | grep -q "run"
            ;;
    esac
}

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

# Get system architecture
system_arch() {
    uname -m
}

# Get kernel version
system_kernel() {
    uname -r
}

# Get init system version
system_init_version() {
    local init="${1:-$(init_detect)}"
    
    case "$init" in
        systemd)
            systemd --version 2>/dev/null | head -1
            ;;
        openrc)
            openrc --version 2>/dev/null
            ;;
        runit)
            runit -v 2>&1 | head -1
            ;;
    esac
}

# Show system info summary
system_info() {
    local pkgmgr
    pkgmgr=$(pkgmgr_detect) || pkgmgr="unknown"
    
    echo "=== System Information ==="
    echo "Distribution:  $(distro_name) ($(distro_detect))"
    echo "Package Mgr:   $(pkgmgr_name "$pkgmgr") ($pkgmgr)"
    echo "Init System:  $(init_detect)"
    echo "Kernel:       $(system_kernel)"
    echo "Architecture: $(system_arch)"
    echo ""
    
    local init
    init=$(init_detect)
    if [[ -n "$init" && "$init" != "unknown" ]]; then
        echo "Init Version: $(system_init_version "$init")"
    fi
}

# =============================================================================
# EXPORT FOR MODULES
# =============================================================================

export -f distro_detect
export -f distro_name
export -f init_detect
export -f pkgmgr_detect
export -f pkgmgr_name
export -f pkg_install
export -f pkg_remove
export -f pkg_search
export -f pkg_installed
export -f svc_enable
export -f svc_start
export -f svc_stop
export -f svc_restart
export -f svc_status
export -f svc_is_enabled
export -f svc_is_active
export -f system_arch
export -f system_kernel
export -f system_init_version
export -f system_info
