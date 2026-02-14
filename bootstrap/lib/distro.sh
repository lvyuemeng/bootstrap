#!/bin/bash
# =============================================================================
# Distribution & Service Management Library
# =============================================================================
# Provides cross-distribution package installation and init system service management
# =============================================================================

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
# PACKAGE MANAGEMENT
# =============================================================================

# Install packages (distribution-aware)
# Usage: pkg_install "package1 package2" [distro]
pkg_install() {
    local packages="$1"
    local distro="${2:-$(distro_detect)}"
    
    if [[ -z "$packages" ]]; then
        echo "No packages to install"
        return 0
    fi
    
    echo "Installing packages: $packages (distro: $distro)"
    
    case "$distro" in
        arch)
            pacman -S --noconfirm $packages
            ;;
        debian|ubuntu|linuxmint)
            export DEBIAN_FRONTEND=noninteractive
            apt update -qq && apt install -y -qq $packages
            ;;
        alpine)
            apk add $packages
            ;;
        void)
            xbps-install -y $packages
            ;;
        gentoo)
            emerge --ask --noreplace $packages
            ;;
        fedora|rhel|centos)
            dnf install -y $packages
            ;;
        opensuse)
            zypper install -y --no-confirm $packages
            ;;
        *)
            echo "Unknown distribution: $distro"
            echo "Please install manually: $packages"
            return 1
            ;;
    esac
}

# Remove packages
# Usage: pkg_remove "package1 package2" [distro]
pkg_remove() {
    local packages="$1"
    local distro="${2:-$(distro_detect)}"
    
    echo "Removing packages: $packages (distro: $distro)"
    
    case "$distro" in
        arch)
            pacman -R --noconfirm $packages
            ;;
        debian|ubuntu)
            apt remove -y $packages
            ;;
        alpine)
            apk del $packages
            ;;
        void)
            xbps-remove -y $packages
            ;;
        gentoo)
            emerge --deselect $packages
            ;;
        fedora|rhel)
            dnf remove -y $packages
            ;;
        *)
            echo "Unknown distribution: $distro"
            return 1
            ;;
    esac
}

# Search for package
# Usage: pkg_search "package-name" [distro]
pkg_search() {
    local pattern="$1"
    local distro="${2:-$(distro_detect)}"
    
    case "$distro" in
        arch)
            pacman -Ss "$pattern"
            ;;
        debian|ubuntu)
            apt search "$pattern"
            ;;
        alpine)
            apk search "$pattern"
            ;;
        void)
            xbps-query -Rs "$pattern"
            ;;
        gentoo)
            emerge --search "$pattern"
            ;;
        fedora|rhel)
            dnf search "$pattern"
            ;;
    esac
}

# Check if package is installed
# Usage: pkg_installed "package" [distro]
pkg_installed() {
    local package="$1"
    local distro="${2:-$(distro_detect)}"
    
    case "$distro" in
        arch)
            pacman -Q "$package" &>/dev/null
            ;;
        debian|ubuntu)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        alpine)
            apk info "$package" &>/dev/null
            ;;
        void)
            xbps-query -e "$package" &>/dev/null
            ;;
        gentoo)
            qlist "$package" &>/dev/null
            ;;
        fedora|rhel)
            rpm -q "$package" &>/dev/null
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
    
    echo "Enabling service: $service (init: $init)"
    
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
            echo "Unknown init system: $init"
            return 1
            ;;
    esac
}

# Start service
# Usage: svc_start "servicename" [init]
svc_start() {
    local service="$1"
    local init="${2:-$(init_detect)}"
    
    echo "Starting service: $service (init: $init)"
    
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
    
    echo "Stopping service: $service (init: $init)"
    
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
    
    echo "Restarting service: $service (init: $init)"
    
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
    echo "=== System Information ==="
    echo "Distribution: $(distro_name) ($(distro_detect))"
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
