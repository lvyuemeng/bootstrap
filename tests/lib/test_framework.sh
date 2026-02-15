#!/bin/bash
# =============================================================================
# Bash Test Framework Library
# =============================================================================
# A reusable, extensible test framework for bash scripts
# =============================================================================

# Color codes
export TEST_COLOR_RED='\033[0;31m'
export TEST_COLOR_GREEN='\033[0;32m'
export TEST_COLOR_YELLOW='\033[1;33m'
export TEST_COLOR_BLUE='\033[0;34m'
export TEST_COLOR_NC='\033[0m' # No Color

# Test counters
export TEST_RUN_COUNT=0
export TEST_PASS_COUNT=0
export TEST_FAIL_COUNT=0
export TEST_SKIP_COUNT=0

# Configuration
export TEST_BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-}"
export TEST_VERBOSE="${TEST_VERBOSE:-0}"

# =============================================================================
# Framework Functions
# =============================================================================

# Initialize test suite
test_suite_init() {
    local suite_name="${1:-Test Suite}"
    echo ""
    echo "=============================================="
    echo "$suite_name"
    echo "=============================================="
    if [[ -n "$TEST_BOOTSTRAP_DIR" ]]; then
        echo "Bootstrap directory: $TEST_BOOTSTRAP_DIR"
    fi
    echo ""
}

# Start a new test
test_start() {
    local test_name="$1"
    ((TEST_RUN_COUNT++))
    echo -e "${TEST_COLOR_YELLOW}[TEST $TEST_RUN_COUNT]${TEST_COLOR_NC} $test_name"
}

# Test passed
test_pass() {
    ((TEST_PASS_COUNT++))
    echo -e "  ${TEST_COLOR_GREEN}✓ PASS${TEST_COLOR_NC}: $1"
}

# Test failed
test_fail() {
    ((TEST_FAIL_COUNT++))
    echo -e "  ${TEST_COLOR_RED}✗ FAIL${TEST_COLOR_NC}: $1"
}

# Test skipped
test_skip() {
    ((TEST_SKIP_COUNT++))
    echo -e "  ${TEST_COLOR_YELLOW}⊘ SKIP${TEST_COLOR_NC}: $1"
}

# Test info
test_info() {
    echo -e "  ${TEST_COLOR_BLUE}ℹ INFO${TEST_COLOR_NC}: $1"
}

# Debug output (only when VERBOSE=1)
test_debug() {
    if [[ "$TEST_VERBOSE" == "1" ]]; then
        echo -e "  DEBUG: $1"
    fi
}

# Assert functions
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    if [[ "$condition" == "0" || "$condition" == "true" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    if [[ "$condition" != "0" && "$condition" != "true" ]]; then
        return 0
    else
        echo "$message"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values not equal}"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File does not exist}"
    if [[ -f "$file" ]]; then
        return 0
    else
        echo "$message: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File does not contain pattern}"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        echo "$message: '$pattern' in $file"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command not found}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        echo "$message: $cmd"
        return 1
    fi
}

# =============================================================================
# Test Runner
# =============================================================================

# Run a single test function
test_run() {
    local test_func="$1"
    local test_args=("${@:2}")
    
    # Reset test state for this run
    local local_pass_count=0
    local local_fail_count=0
    
    # Run the test
    if "$test_func" "${test_args[@]}"; then
        return 0
    else
        return 1
    fi
}

# Print test summary
test_suite_summary() {
    echo ""
    echo "=============================================="
    echo "Test Summary"
    echo "=============================================="
    echo -e "Tests run:    $TEST_RUN_COUNT"
    echo -e "Tests passed: ${TEST_COLOR_GREEN}$TEST_PASS_COUNT${TEST_COLOR_NC}"
    echo -e "Tests failed: ${TEST_COLOR_RED}$TEST_FAIL_COUNT${TEST_COLOR_NC}"
    echo -e "Tests skipped: ${TEST_COLOR_YELLOW}$TEST_SKIP_COUNT${TEST_COLOR_NC}"
    echo ""
    
    if [[ "$TEST_FAIL_COUNT" -gt 0 ]]; then
        echo -e "${TEST_COLOR_RED}SOME TESTS FAILED${TEST_COLOR_NC}"
        return 1
    else
        echo -e "${TEST_COLOR_GREEN}ALL TESTS PASSED${TEST_COLOR_NC}"
        return 0
    fi
}

# Reset test counters
test_suite_reset() {
    TEST_RUN_COUNT=0
    TEST_PASS_COUNT=0
    TEST_FAIL_COUNT=0
    TEST_SKIP_COUNT=0
}

# =============================================================================
# Module Loading Helpers
# =============================================================================

# Source a library file with error handling
test_load_lib() {
    local lib_path="$1"
    
    if [[ ! -f "$lib_path" ]]; then
        echo "ERROR: Library not found: $lib_path"
        return 1
    fi
    
    source "$lib_path"
}

# =============================================================================
# Export functions for use in other scripts
# =============================================================================

export -f test_suite_init
export -f test_start
export -f test_pass
export -f test_fail
export -f test_skip
export -f test_info
export -f test_debug
export -f assert_true
export -f assert_false
export -f assert_equals
export -f assert_file_exists
export -f assert_file_contains
export -f assert_command_exists
export -f test_run
export -f test_suite_summary
export -f test_suite_reset
export -f test_load_lib
