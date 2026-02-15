#!/bin/bash
# =============================================================================
# Logging Library
# =============================================================================
# Provides structured logging with levels: debug, info, warn, error
# Supports console output with colors and file logging with rotation
# =============================================================================

# Bootstrap directory (fallback)
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# =============================================================================
# Log Configuration
# =============================================================================

# Log levels (numeric for comparison)
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-${LOG_LEVEL_INFO}}"

# Convert string to level number
case "${LOG_LEVEL}" in
    debug|DEBUG|0) LOG_LEVEL=0 ;;
    info|INFO|1)    LOG_LEVEL=1 ;;
    warn|WARN|2)   LOG_LEVEL=2 ;;
    error|ERROR|3) LOG_LEVEL=3 ;;
esac

# Log file configuration
LOG_FILE="${LOG_FILE:-${BOOTSTRAP_DIR}/logs/bootstrap.log}"
LOG_DIR="$(dirname "$LOG_FILE")"
LOG_MAX_SIZE=$((10 * 1024 * 1024))  # 10MB

# Color codes (if terminal supports it)
if [[ -t 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_GREEN='\033[0;32m'
    COLOR_GRAY='\033[0;90m'
else
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_YELLOW=''
    COLOR_GREEN=''
    COLOR_GRAY=''
fi

# Verbose mode (enables debug)
VERBOSE="${VERBOSE:-0}"

# =============================================================================
# Log Initialization
# =============================================================================

# Initialize log directory and file
log_init() {
    mkdir -p "$LOG_DIR"
    
    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi
    
    # Check if rotation is needed
    log_rotate
}

# Rotate log file if too large
log_rotate() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        
        if [[ $size -gt $LOG_MAX_SIZE ]]; then
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            local rotated="${LOG_FILE}.${timestamp}"
            
            mv "$LOG_FILE" "$rotated"
            touch "$LOG_FILE"
            
            # Keep only last 5 rotated logs
            ls -1t "${LOG_FILE}".* 2>/dev/null | tail -n +6 | xargs -r rm -f
        fi
    fi
}

# =============================================================================
# Core Logging Functions
# =============================================================================

# Write to log file (internal)
_log_write() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log file exists
    log_init
    
    # Write to file with structured format
    echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
}

# Debug log (only if VERBOSE=1)
log_debug() {
    local message="$*"
    
    # Only log if verbose mode is enabled
    if [[ "$VERBOSE" == "1" || "$VERBOSE" == "true" ]]; then
        _log_write "DEBUG" "$message"
        echo -e "${COLOR_GRAY}[DEBUG]${COLOR_RESET} ${message}"
    fi
}

# Info log (normal operation messages)
log_info() {
    local message="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        _log_write "INFO" "$message"
        echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} ${message}"
    fi
}

# Warning log (non-fatal issues)
log_warn() {
    local message="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        _log_write "WARN" "$message"
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} ${message}" >&2
    fi
}

# Error log (fatal issues)
log_error() {
    local message="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        _log_write "ERROR" "$message"
        echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} ${message}" >&2
    fi
}

# =============================================================================
# Convenience Functions
# =============================================================================

# Log command output (captures both stdout and stderr)
log_cmd() {
    local cmd="$*"
    local output
    local status
    
    output=$("$cmd" 2>&1)
    status=$?
    
    if [[ $status -eq 0 ]]; then
        log_info "$cmd succeeded"
        [[ -n "$output" ]] && log_debug "$output"
    else
        log_error "$cmd failed (exit status: $status)"
        [[ -n "$output" ]] && log_debug "$output"
    fi
    
    return $status
}

# Log success message with checkmark
log_success() {
    local message="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        _log_write "INFO" "✓ ${message}"
        echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${message}"
    fi
}

# Log failure message with X mark
log_fail() {
    local message="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        _log_write "ERROR" "✗ ${message}"
        echo -e "${COLOR_RED}✗${COLOR_RESET} ${message}" >&2
    fi
}

# Log section header
log_section() {
    local title="$*"
    
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        _log_write "INFO" "==== $title ===="
        echo ""
        echo "==== $title ===="
    fi
}

# =============================================================================
# Log Query Functions
# =============================================================================

# Get last N lines from log
log_tail() {
    local lines="${1:-10}"
    
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "$lines" "$LOG_FILE"
    fi
}

# Search log for pattern
log_grep() {
    local pattern="$1"
    
    if [[ -f "$LOG_FILE" ]]; then
        grep "$pattern" "$LOG_FILE"
    fi
}

# Show log summary (error count, warn count, etc)
log_summary() {
    local errors=0 warnings=0
    
    if [[ -f "$LOG_FILE" ]]; then
        errors=$(grep -c " \[ERROR\]" "$LOG_FILE" 2>/dev/null || echo 0)
        warnings=$(grep -c " \[WARN\]" "$LOG_FILE" 2>/dev/null || echo 0)
    fi
    
    echo "Log Summary:"
    echo "  Errors:   $errors"
    echo "  Warnings: $warnings"
    echo "  Log file: $LOG_FILE"
}

# Export functions
export -f log_init
export -f log_rotate
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_cmd
export -f log_success
export -f log_fail
export -f log_section
export -f log_tail
export -f log_grep
export -f log_summary
