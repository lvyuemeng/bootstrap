#!/bin/bash
# =============================================================================
# Module Proof/Verification Framework
# =============================================================================
# Provides bottom-to-top proof verification for each module
# Each module must prove its requirements are met before proceeding
# =============================================================================

# Proof verification state
PROOF_LOG_DIR="${BOOTSTRAP_DIR}/logs/proofs"
PROOF_STATE_DIR="${BOOTSTRAP_DIR}/state"
PROOF_VERIFIED_MODULES=()
PROOF_FAILED_MODULES=()

# Proof result codes
PROOF_PASS=0
PROOF_FAIL=1
PROOF_SKIP=2
PROOF_PENDING=3

# =============================================================================
# Proof Engine Core
# =============================================================================

# Initialize proof system
proof_init() {
    mkdir -p "$PROOF_LOG_DIR"
    mkdir -p "$PROOF_STATE_DIR"
    
    # Load previous proof state if exists
    if [[ -f "$PROOF_STATE_DIR/verified.modules" ]]; then
        readarray -t PROOF_VERIFIED_MODULES < "$PROOF_STATE_DIR/verified.modules"
    fi
    
    echo "Proof system initialized"
    echo "Previously verified: ${#PROOF_VERIFIED_MODULES[@]} modules"
}

# Clear proof state (force re-verification)
proof_reset() {
    rm -rf "$PROOF_LOG_DIR"/*
    rm -rf "$PROOF_STATE_DIR"/*
    PROOF_VERIFIED_MODULES=()
    PROOF_FAILED_MODULES=()
    echo "Proof state reset"
}

# Log proof result
proof_log() {
    local module="$1"
    local result="$2"
    local details="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$PROOF_LOG_DIR"
    
    local log_file="$PROOF_LOG_DIR/${module}.log"
    {
        echo "=== Proof Verification ==="
        echo "Timestamp: $timestamp"
        echo "Module: $module"
        echo "Result: $result"
        echo ""
        echo "=== Details ==="
        echo "$details"
        echo ""
    } >> "$log_file"
}

# Save verified module state
proof_save_state() {
    printf '%s\n' "${PROOF_VERIFIED_MODULES[@]}" > "$PROOF_STATE_DIR/verified.modules"
}

# =============================================================================
# Proof Verification Functions
# =============================================================================

# Check if module was already verified successfully
proof_is_verified() {
    local module="$1"
    for verified in "${PROOF_VERIFIED_MODULES[@]}"; do
        [[ "$verified" == "$module" ]] && return 0
    done
    return 1
}

# Check if module previously failed
proof_has_failed() {
    local module="$1"
    for failed in "${PROOF_FAILED_MODULES[@]}"; do
        [[ "$failed" == "$module" ]] && return 0
    done
    return 1
}

# Mark module as verified
proof_mark_verified() {
    local module="$1"
    proof_is_verified "$module" && return 0
    
    PROOF_VERIFIED_MODULES+=("$module")
    proof_save_state
    echo "[PROOF] ✓ $module verified"
}

# Mark module as failed
proof_mark_failed() {
    local module="$1"
    PROOF_FAILED_MODULES+=("$module")
    echo "[PROOF] ✗ $module failed verification"
}

# =============================================================================
# Proof Check Functions (Atomic Verification Primitives)
# =============================================================================

# Proof: Process is running
proof_process() {
    local process_name="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if pgrep -x "$process_name" >/dev/null 2>&1; then
        result=$PROOF_PASS
        details="Process '$process_name' is running"
    else
        details="Process '$process_name' not found"
    fi
    
    proof_log "process:$process_name" "$result" "$details"
    return $result
}

# Proof: Service is active (systemd)
proof_service_active() {
    local service="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        result=$PROOF_PASS
        details="Service '$service' is active"
    else
        details="Service '$service' is not active"
    fi
    
    proof_log "service:$service" "$result" "$details"
    return $result
}

# Proof: Service is enabled
proof_service_enabled() {
    local service="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        result=$PROOF_PASS
        details="Service '$service' is enabled"
    else
        details="Service '$service' is not enabled"
    fi
    
    proof_log "service-enabled:$service" "$result" "$details"
    return $result
}

# Proof: D-Bus service exists
proof_dbus_service() {
    local bus_name="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | \
        grep -q "\"$bus_name\""; then
        result=$PROOF_PASS
        details="D-Bus service '$bus_name' is registered"
    else
        details="D-Bus service '$bus_name' not found"
    fi
    
    proof_log "dbus:$bus_name" "$result" "$details"
    return $result
}

# Proof: Kernel module is loaded
proof_kernel_module() {
    local module="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if lsmod | grep -q "^${module} "; then
        result=$PROOF_PASS
        details="Kernel module '$module' is loaded"
    else
        details="Kernel module '$module' is not loaded"
    fi
    
    proof_log "kernel:$module" "$result" "$details"
    return $result
}

# Proof: Device exists
proof_device() {
    local device_path="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if [[ -e "$device_path" ]]; then
        result=$PROOF_PASS
        details="Device '$device_path' exists"
    else
        details="Device '$device_path' not found"
    fi
    
    proof_log "device:$device_path" "$result" "$details"
    return $result
}

# Proof: File exists with content
proof_file() {
    local file_path="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if [[ -f "$file_path" ]]; then
        result=$PROOF_PASS
        local size
        size=$(stat -c%s "$file_path" 2>/dev/null || echo "unknown")
        details="File '$file_path' exists (size: $size)"
    else
        details="File '$file_path' not found"
    fi
    
    proof_log "file:$file_path" "$result" "$details"
    return $result
}

# Proof: File contains pattern
proof_file_contains() {
    local file_path="$1"
    local pattern="$2"
    local details=""
    local result=$PROOF_FAIL
    
    if [[ -f "$file_path" && "$file_path" =~ $pattern ]]; then
        result=$PROOF_PASS
        details="File '$file_path' contains pattern '$pattern'"
    else
        details="File '$file_path' does not contain pattern '$pattern'"
    fi
    
    proof_log "file-contains:$file_path" "$result" "$details"
    return $result
}

# Proof: Command is available
proof_command() {
    local cmd="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if command -v "$cmd" >/dev/null 2>&1; then
        result=$PROOF_PASS
        local path
        path=$(command -v "$cmd")
        details="Command '$cmd' available at: $path"
    else
        details="Command '$cmd' not found"
    fi
    
    proof_log "command:$cmd" "$result" "$details"
    return $result
}

# Proof: User exists
proof_user() {
    local username="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if id "$username" >/dev/null 2>&1; then
        result=$PROOF_PASS
        details="User '$username' exists"
    else
        details="User '$username' not found"
    fi
    
    proof_log "user:$username" "$result" "$details"
    return $result
}

# Proof: User is in group
proof_user_in_group() {
    local username="$1"
    local group="$2"
    local details=""
    local result=$PROOF_FAIL
    
    if groups "$username" 2>/dev/null | grep -qw "$group"; then
        result=$PROOF_PASS
        details="User '$username' is in group '$group'"
    else
        details="User '$username' is not in group '$group'"
    fi
    
    proof_log "user-group:$username:$group" "$result" "$details"
    return $result
}

# Proof: Network interface is up
proof_network_interface() {
    local interface="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if ip link show "$interface" 2>/dev/null | grep -q "state UP"; then
        result=$PROOF_PASS
        details="Network interface '$interface' is UP"
    else
        details="Network interface '$interface' is not UP"
    fi
    
    proof_log "net:$interface" "$result" "$details"
    return $result
}

# Proof: Can resolve DNS
proof_dns_resolve() {
    local host="${1:-google.com}"
    local details=""
    local result=$PROOF_FAIL
    
    if getent hosts "$host" >/dev/null 2>&1 || nslookup "$host" >/dev/null 2>&1; then
        result=$PROOF_PASS
        details="DNS resolution for '$host' works"
    else
        details="Cannot resolve '$host'"
    fi
    
    proof_log "dns:$host" "$result" "$details"
    return $result
}

# Proof: Port is listening
proof_port_listening() {
    local port="$1"
    local details=""
    local result=$PROOF_FAIL
    
    if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        result=$PROOF_PASS
        details="Port $port is listening"
    else
        details="Port $port is not listening"
    fi
    
    proof_log "port:$port" "$result" "$details"
    return $result
}

# =============================================================================
# Module Verification
# =============================================================================

# Verify a module's requirements
# Usage: proof_verify_module "module_name" "requirement1" "requirement2"
# Each requirement is a function name followed by arguments
proof_verify_module() {
    local module="$1"
    shift
    local requirements=("$@")
    
    echo ""
    echo "=== Verifying module: $module ==="
    
    # Skip if already verified
    if proof_is_verified "$module"; then
        echo "[PROOF] Module '$module' already verified, skipping"
        return 0
    fi
    
    # Skip if previously failed (avoid infinite loops)
    if proof_has_failed "$module"; then
        echo "[PROOF] Module '$module' previously failed, skipping"
        return 1
    fi
    
    local all_passed=true
    local details=""
    
    for req in "${requirements[@]}"; do
        # Parse requirement: "function:arg1:arg2"
        local func="${req%%:*}"
        local args="${req#*:}"
        IFS=':' read -ra arg_array <<< "$args"
        
        # Call verification function
        echo -n "  Checking $func... "
        if "$func" "${arg_array[@]}"; then
            echo "✓"
        else
            echo "✗"
            all_passed=false
        fi
    done
    
    if $all_passed; then
        proof_mark_verified "$module"
        return 0
    else
        proof_mark_failed "$module"
        return 1
    fi
}

# =============================================================================
# Bottom-to-Top Verification (Dependency Order)
# =============================================================================

# Verify module and all its dependencies (bottom-to-top)
# Usage: proof_verify_chain "module_name" "dep1" "dep2"
proof_verify_chain() {
    local target="$1"
    shift
    local dependencies=("$@")
    
    echo ""
    echo "=== Bottom-to-Top Verification Chain ==="
    echo "Target: $target"
    echo "Dependencies: ${dependencies[*]}"
    echo ""
    
    local -A visited
    local -a verify_order
    
    # Build verification order (bottom-up)
    _build_order() {
        local mod="$1"
        
        [[ "${visited[$mod]}" == "1" ]] && return 0
        visited[$mod]=1
        
        # First verify dependencies
        for dep in "${dependencies[@]}"; do
            if [[ "$dep" == "$mod" ]]; then
                continue  # Skip self-reference
            fi
            _build_order "$dep"
        done
        
        # Then add this module
        verify_order+=("$mod")
    }
    
    _build_order "$target"
    
    # Execute verification in order
    local failed=false
    for mod in "${verify_order[@]}"; do
        # Construct requirements for this module
        local -a reqs=()
        
        # Base requirements for any module
        if [[ "$mod" == "dbus" ]]; then
            reqs=("proof_process:dbus-daemon")
        elif [[ "$mod" == "network-manager" ]]; then
            reqs=("proof_process:NetworkManager")
        elif [[ "$mod" == "audio-pipewire" ]]; then
            reqs=("proof_process:pipewire")
        elif [[ "$mod" == "bluetooth-stack" ]]; then
            reqs=("proof_process:bluetoothd" "proof_dbus_service:org.bluez")
        fi
        
        # Verify this module
        if ! proof_verify_module "$mod" "${reqs[@]}"; then
            failed=true
            break
        fi
    done
    
    if $failed; then
        echo ""
        echo "[PROOF] Chain verification FAILED"
        return 1
    fi
    
    echo ""
    echo "[PROOF] Chain verification PASSED"
    return 0
}

# =============================================================================
# Proof Report
# =============================================================================

# Generate verification report
proof_report() {
    echo ""
    echo "========================================"
    echo "       MODULE PROOF REPORT"
    echo "========================================"
    echo ""
    echo "Verified Modules (${#PROOF_VERIFIED_MODULES[@]}):"
    for mod in "${PROOF_VERIFIED_MODULES[@]}"; do
        echo "  ✓ $mod"
    done
    echo ""
    
    if [[ ${#PROOF_FAILED_MODULES[@]} -gt 0 ]]; then
        echo "Failed Modules (${#PROOF_FAILED_MODULES[@]}):"
        for mod in "${PROOF_FAILED_MODULES[@]}"; do
            echo "  ✗ $mod"
        done
        echo ""
    fi
    
    echo "Proof Logs: $PROOF_LOG_DIR"
    echo "Proof State: $PROOF_STATE_DIR"
}

# Quick proof check - run all proof functions for a module
proof_check() {
    local module="$1"
    
    echo "=== Running proofs for: $module ==="
    
    # Check module-specific proofs
    case "$module" in
        dbus)
            proof_process "dbus-daemon"
            proof_service_active "dbus"
            ;;
        bluetooth-stack)
            proof_process "bluetoothd"
            proof_dbus_service "org.bluez"
            proof_kernel_module "btusb"
            ;;
        network-manager)
            proof_process "NetworkManager"
            proof_service_active "NetworkManager"
            ;;
        audio-pipewire)
            proof_process "pipewire"
            proof_process "wireplumber"
            ;;
        x11-server)
            proof_command "Xorg"
            proof_process "Xorg"
            ;;
        *)
            echo "No specific proofs for: $module"
            ;;
    esac
}
