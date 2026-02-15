#!/bin/bash
# =============================================================================
# State Management Library
# =============================================================================
# Provides minimal JSON state tracking for installed modules
# =============================================================================

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Load logging
source "${BOOTSTRAP_DIR}/lib/log.sh"

# State file location
STATE_FILE="${HOME}/.config/bootstrap/state.json"

# =============================================================================
# State Operations
# =============================================================================

# Initialize state file
state_init() {
    local state_dir
    state_dir=$(dirname "$STATE_FILE")
    
    mkdir -p "$state_dir"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"modules": {},"last_run": null}' > "$STATE_FILE"
        log_debug "Created state file: $STATE_FILE"
    fi
}

# Load state
state_load() {
    state_init
    
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"modules": {}}'
    fi
}

# Save state
state_save() {
    local state_file="$1"
    
    state_init
    
    if [[ -n "$state_file" ]]; then
        cat "$state_file" > "$STATE_FILE"
    fi
}

# Get module state
state_get() {
    local module="$1"
    local state
    state=$(state_load)
    
    # Simple JSON parsing with grep/sed
    local value
    value=$(echo "$state" | grep -o "\"$module\": *{[^}]*}" | sed "s/.*\"installed\": *\([^,}]*\).*/\1/" | tr -d ' "')
    
    echo "${value:-null}"
}

# Set module state
state_set() {
    local module="$1"
    local status="$2"  # installed, failed, pending
    
    state_init
    
    local state
    state=$(state_load)
    
    # Check if module exists in state
    if echo "$state" | grep -q "\"$module\":"; then
        # Update existing
        state=$(echo "$state" | sed "s/\"$module\": *{[^}]*}/\"$module\": {\"status\": \"$status\", \"timestamp\": \"$(date -Iseconds)\"}/")
    else
        # Add new
        state=$(echo "$state" | sed 's/}$/, "'"$module"'": {"status": "'"$status"'", "timestamp": "'"$(date -Iseconds)"'"}}/' | sed 's/, }$/}/')
    fi
    
    echo "$state" > "$STATE_FILE"
}

# Remove module state
state_remove() {
    local module="$1"
    
    state_init
    
    local state
    state=$(state_load)
    
    # Remove module from state
    state=$(echo "$state" | sed 's/,"'"$module"'": {[^}]*}//' | sed 's/'"$module"': {[^}]*},//' | sed 's/'"$module"': {[^}]*}//')
    
    echo "$state" > "$STATE_FILE"
}

# Get all installed modules
state_list_installed() {
    local state
    state=$(state_load)
    
    echo "$state" | grep -o '"[^"]*": *{"status": *"installed"' | sed 's/": *{.*//' | tr -d '"'
}

# Check if module is installed
state_is_installed() {
    local module="$1"
    local status
    status=$(state_get "$module")
    
    [[ "$status" == "installed" ]]
}

# Clear all state
state_clear() {
    echo '{"modules": {},"last_run": null}' > "$STATE_FILE"
    log_info "State cleared"
}

# Update last run timestamp
state_touch() {
    state_init
    
    local state
    state=$(state_load)
    
    state=$(echo "$state" | sed 's/"last_run": *[^,]*/"last_run": "'"$(date -Iseconds)"'"/')
    
    echo "$state" > "$STATE_FILE"
}
