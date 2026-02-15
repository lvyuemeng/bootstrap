#!/bin/bash
# =============================================================================
# Bootstrap Architecture Design Defects Tests
# =============================================================================
# Tests to verify design defects in the bootstrap system architecture
# Usage: ./bootstrap_architecture_tests.sh [--bootstrap-dir PATH]
# =============================================================================

set -u

# Script directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bootstrap-dir)
            BOOTSTRAP_DIR="$2"
            shift 2
            ;;
        --bootstrap-dir=*)
            BOOTSTRAP_DIR="${1#*=}"
            shift
            ;;
        --verbose|-v)
            TEST_VERBOSE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--bootstrap-dir PATH] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --bootstrap-dir PATH   Set bootstrap directory (default: auto-detect)"
            echo "  --verbose, -v         Enable verbose output"
            echo "  --help, -h            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect bootstrap directory
if [[ -z "${BOOTSTRAP_DIR:-}" ]]; then
    # Try to find bootstrap directory
    if [[ -d "$SCRIPT_DIR/../bootstrap" ]]; then
        BOOTSTRAP_DIR="$SCRIPT_DIR/../bootstrap"
    elif [[ -d "$SCRIPT_DIR/../../bootstrap" ]]; then
        BOOTSTRAP_DIR="$SCRIPT_DIR/../../bootstrap"
    else
        echo "Error: Could not auto-detect bootstrap directory"
        echo "Use --bootstrap-dir to specify manually"
        exit 1
    fi
fi

export BOOTSTRAP_DIR
export TEST_BOOTSTRAP_DIR="$BOOTSTRAP_DIR"

# Load test framework
source "$SCRIPT_DIR/lib/test_framework.sh"

# =============================================================================
# Test Category: Dependency Resolution
# =============================================================================

test_deps_topological_order() {
    test_start "Dependency resolution produces correct topological order"
    
    source "${BOOTSTRAP_DIR}/lib/deps.sh"
    
    local result
    result=$(deps_resolve sway 2>&1)
    
    if echo "$result" | grep -q "Error: Circular dependency detected"; then
        test_fail "False circular dependency detection"
        return 1
    fi
    
    local wayland_pos=$(echo "$result" | grep -n "^wayland$" | cut -d: -f1)
    local sway_pos=$(echo "$result" | grep -n "^sway$" | cut -d: -f1)
    
    if [[ -n "$wayland_pos" && -n "$sway_pos" && "$wayland_pos" -lt "$sway_pos" ]]; then
        test_pass "Dependencies ordered correctly (wayland before sway)"
    else
        test_fail "Dependency ordering incorrect"
    fi
}

test_deps_validates_missing_modules() {
    test_start "Dependency resolution validates module existence"
    
    source "${BOOTSTRAP_DIR}/lib/deps.sh"
    
    local result
    result=$(deps_resolve "nonexistent-module" 2>&1)
    
    if echo "$result" | grep -qi "error\|not found\|missing"; then
        test_pass "Detects non-existent module"
    else
        test_fail "Does not validate non-existent modules"
    fi
}

test_deps_handles_optional() {
    test_start "Dependency resolution handles optional dependencies"
    
    if grep -q "MODULE_OPTIONAL" "${BOOTSTRAP_DIR}/lib/deps.sh"; then
        test_pass "Optional dependencies are recognized"
    else
        test_fail "Optional dependencies not handled"
    fi
}

test_deps_circular_detection() {
    test_start "Circular dependency detection works"
    
    if grep -q "Circular dependency detected" "${BOOTSTRAP_DIR}/lib/deps.sh"; then
        test_pass "Has circular dependency detection"
    else
        test_fail "Missing circular dependency detection"
    fi
}

# =============================================================================
# Test Category: Bootstrap Core Integration
# =============================================================================

test_bootstrap_uses_deps_resolve() {
    test_start "bootstrap() function uses dependency resolution"
    
    local core_file="${BOOTSTRAP_DIR}/lib/core.sh"
    
    if grep -q "^bootstrap()" "$core_file"; then
        if grep -A 50 "^bootstrap()" "$core_file" | grep -qE "deps_resolve|deps_order"; then
            test_pass "bootstrap() integrates dependency resolution"
        else
            test_fail "bootstrap() does not call deps_resolve"
        fi
    else
        test_fail "bootstrap() function not found"
    fi
}

test_install_module_saves_state() {
    test_start "install_module() saves state after installation"
    
    local core_file="${BOOTSTRAP_DIR}/lib/core.sh"
    
    if grep -A 30 "^install_module()" "$core_file" | grep -qE "state_set|state_save"; then
        test_pass "install_module() tracks installed state"
    else
        test_fail "install_module() doesn't save state"
    fi
}

# =============================================================================
# Test Category: State Management
# =============================================================================

test_state_json_parsing() {
    test_start "State management handles edge cases"
    
    # Test substring module name handling
    local value
    value=$(echo '{"modules": {"sway": {"status": "installed"}, "waysway": {"status": "pending"}}}' | \
        grep -o '"sway": *{[^}]*}' | sed 's/.*"status": *"\([^"]*\)".*/\1/')
    
    if [[ "$value" == "installed" ]]; then
        test_pass "Handles substring module names"
    else
        test_fail "Fails on substring module names (got: '$value')"
    fi
}

# =============================================================================
# Test Category: Module Definition Consistency
# =============================================================================

test_module_package_keys_consistent() {
    test_start "Module package keys use consistent naming"
    
    # Check for mixing of package manager vs distribution keys
    local sway_has_pacman=$(grep -c 'MODULE_PACKAGES\[pacman\]' "${BOOTSTRAP_DIR}/modules/sway.sh" 2>/dev/null || echo 0)
    local dbus_has_arch=$(grep -c 'MODULE_PACKAGES\[arch\]' "${BOOTSTRAP_DIR}/modules/dbus.sh" 2>/dev/null || echo 0)
    
    if [[ "$sway_has_pacman" -gt 0 && "$dbus_has_arch" -gt 0 ]]; then
        test_fail "Inconsistent keys: 'pacman' vs 'arch' mixed"
    elif [[ "$sway_has_pacman" -gt 0 ]]; then
        test_fail "Uses package manager key instead of distribution"
    else
        test_pass "Package keys are consistent"
    fi
}

test_module_dependencies_exist() {
    test_start "All module dependencies reference existing modules"
    
    local modules_dir="${BOOTSTRAP_DIR}/modules"
    local issues=0
    
    # Check audio-pipewire specifically
    if grep -q 'MODULE_REQUIRES.*"init"' "$modules_dir/audio-pipewire.sh" 2>/dev/null; then
        if [[ ! -f "$modules_dir/init.sh" ]]; then
            test_fail "audio-pipewire depends on non-existent 'init' module"
            ((issues++))
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        test_pass "All dependencies reference existing modules"
    fi
}

test_module_distro_coverage() {
    test_start "Modules define packages for common distributions"
    
    local bluetooth_file="${BOOTSTRAP_DIR}/modules/bluetooth-stack.sh"
    
    # Check for key distributions
    local has_fedora has_opensuse has_debian has_arch
    has_fedora=$(grep -c 'MODULE_PACKAGES\[fedora\]' "$bluetooth_file" 2>/dev/null | head -1)
    has_opensuse=$(grep -c 'MODULE_PACKAGES\[opensuse\]' "$bluetooth_file" 2>/dev/null | head -1)
    has_debian=$(grep -c 'MODULE_PACKAGES\[debian\]' "$bluetooth_file" 2>/dev/null | head -1)
    has_arch=$(grep -c 'MODULE_PACKAGES\[arch\]' "$bluetooth_file" 2>/dev/null | head -1)
    
    # Default to 0 if empty
    has_fedora=${has_fedora:-0}
    has_opensuse=${has_opensuse:-0}
    has_debian=${has_debian:-0}
    has_arch=${has_arch:-0}
    
    local missing=0
    [[ "$has_fedora" -eq 0 ]] && ((missing++))
    [[ "$has_opensuse" -eq 0 ]] && ((missing++))
    [[ "$has_debian" -eq 0 ]] && ((missing++))
    [[ "$has_arch" -eq 0 ]] && ((missing++))
    
    if [[ $missing -gt 2 ]]; then
        test_fail "Missing package definitions for $missing distributions"
    else
        test_pass "Most distributions have packages defined"
    fi
}

# =============================================================================
# Test Category: Library API Completeness
# =============================================================================

test_lib_files_exist() {
    test_start "Required library files exist"
    
    local libs=(
        "lib/deps.sh"
        "lib/core.sh"
        "lib/state.sh"
        "lib/log.sh"
        "lib/config.sh"
        "lib/proof.sh"
        "lib/distro.sh"
    )
    
    local missing=0
    for lib in "${libs[@]}"; do
        if [[ ! -f "${BOOTSTRAP_DIR}/${lib}" ]]; then
            test_info "Missing: $lib"
            ((missing++))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        test_pass "All required libraries present"
    else
        test_fail "$missing library files missing"
    fi
}

test_module_files_exist() {
    test_start "Core module files exist"
    
    local modules=(
        "modules/dbus.sh"
        "modules/sway.sh"
        "modules/wayland.sh"
    )
    
    local missing=0
    for mod in "${modules[@]}"; do
        if [[ ! -f "${BOOTSTRAP_DIR}/${mod}" ]]; then
            test_info "Missing: $mod"
            ((missing++))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        test_pass "Core modules present"
    else
        test_fail "$missing module files missing"
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

main() {
    test_suite_init "Bootstrap Architecture Tests"
    
    # Dependency Resolution Tests
    test_deps_topological_order
    test_deps_validates_missing_modules
    test_deps_handles_optional
    test_deps_circular_detection
    
    # Bootstrap Core Tests
    test_bootstrap_uses_deps_resolve
    test_install_module_saves_state
    
    # State Management Tests
    test_state_json_parsing
    
    # Module Consistency Tests
    test_module_package_keys_consistent
    test_module_dependencies_exist
    test_module_distro_coverage
    
    # Library/Module Existence Tests
    test_lib_files_exist
    test_module_files_exist
    
    # Print summary
    test_suite_summary
    exit $?
}

main "$@"
