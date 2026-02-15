#!/bin/bash
# =============================================================================
# Dependency Resolution Library
# =============================================================================
# Provides topological sort for module dependencies
# =============================================================================

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Load logging
source "${BOOTSTRAP_DIR}/lib/log.sh"

# =============================================================================
# Load Module Metadata
# =============================================================================

# Load module without executing
_load_module_meta() {
    local module_name="$1"
    local module_file="${BOOTSTRAP_DIR}/modules/${module_name}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module_name"
        return 1
    fi
    
    # Source module in subshell to get definitions
    (
        source "$module_file"
        
        # Export module metadata
        echo "MODULE_NAME=${MODULE_NAME:-${module_name}}"
        echo "MODULE_REQUIRES=${MODULE_REQUIRES[*]}"
        echo "MODULE_OPTIONAL=${MODULE_OPTIONAL[*]}"
    )
}

# Get module requires (dependencies)
_get_requires() {
    local module_name="$1"
    local module_file="${BOOTSTRAP_DIR}/modules/${module_name}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        return 1
    fi
    
    # Source and get requires
    local requires
    requires=$(
        source "$module_file" 2>/dev/null
        echo "${MODULE_REQUIRES[*]:-}"
    )
    
    echo "$requires"
}

# Get all available modules
deps_list_modules() {
    local modules=()
    
    for file in "${BOOTSTRAP_DIR}"/modules/*.sh; do
        if [[ -f "$file" ]]; then
            local name
            name=$(basename "$file" .sh)
            modules+=("$name")
        fi
    done
    
    printf '%s\n' "${modules[@]}"
}

# =============================================================================
# Topological Sort
# =============================================================================

# Build dependency graph
_build_deps_graph() {
    local -n graph="$1"
    local modules=("${@:2}")
    
    for module in "${modules[@]}"; do
        local requires
        requires=$(_get_requires "$module")
        
        if [[ -n "$requires" ]]; then
            graph["$module"]="$requires"
        else
            graph["$module"]=""
        fi
    done
}

# Topological sort using Kahn's algorithm
deps_resolve() {
    local -a input_modules=("$@")
    
    if [[ ${#input_modules[@]} -eq 0 ]]; then
        return
    fi
    
    declare -A in_degree
    
    # Initialize all modules (including deps)
    local -a all_modules=("${input_modules[@]}")
    
    # Add all transitive dependencies
    local -a queue=("${input_modules[@]}")
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        
        local requires
        requires=$(_get_requires "$current")
        
        for dep in $requires; do
            # Check if dep module exists
            if [[ -f "${BOOTSTRAP_DIR}/modules/${dep}.sh" ]]; then
                # Add to all_modules if not present
                local found=0
                for m in "${all_modules[@]}"; do
                    [[ "$m" == "$dep" ]] && found=1
                done
                if [[ $found -eq 0 ]]; then
                    all_modules+=("$dep")
                    queue+=("$dep")
                fi
            fi
        done
    done
    
    # Build in-degree map
    for module in "${all_modules[@]}"; do
        in_degree["$module"]=0
    done
    
    # Calculate in-degrees
    for module in "${all_modules[@]}"; do
        local requires
        requires=$(_get_requires "$module")
        
        for dep in $requires; do
            # Only count deps that exist in our set
            for m in "${all_modules[@]}"; do
                [[ "$m" == "$dep" ]] && ((in_degree["$module"]++))
            done
        done
    done
    
    # Kahn's algorithm
    local -a queue=()
    local -a result=()
    
    # Start with modules that have no dependencies
    for module in "${all_modules[@]}"; do
        if [[ ${in_degree["$module"]} -eq 0 ]]; then
            queue+=("$module")
        fi
    done
    
    while [[ ${#queue[@]} -gt 0 ]]; do
        # Sort queue for deterministic output
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        
        result+=("$current")
        
        # Find modules that depend on current
        for module in "${all_modules[@]}"; do
            local requires
            requires=$(_get_requires "$module")
            
            for dep in $requires; do
                if [[ "$dep" == "$current" ]]; then
                    ((in_degree["$module"]--))
                    if [[ ${in_degree["$module"]} -eq 0 ]]; then
                        queue+=("$module")
                    fi
                fi
            done
        done
    done
    
    # Check for cycles
    if [[ ${#result[@]} -ne ${#all_modules[@]} ]]; then
        echo "Error: Circular dependency detected" >&2
        return 1
    fi
    
    # Return ordered list
    printf '%s\n' "${result[@]}"
}

# Get install order for modules
deps_order() {
    deps_resolve "$@"
}

# Check if dependency is satisfied
deps_satisfied() {
    local dep="$1"
    shift
    local modules=("$@")
    
    for m in "${modules[@]}"; do
        [[ "$m" == "$dep" ]] && return 0
    done
    
    return 1
}

# Show dependency tree
deps_tree() {
    local module="$1"
    local indent="${2:-0}"
    local visited="${3:-}"
    
    # Check for cycle
    for v in $visited; do
        if [[ "$v" == "$module" ]]; then
            log_error "[CYCLE: $module]"
            return
        fi
    done
    
    visited="$visited $module"
    
    printf "%-${indent}s%s\n" "" "$module"
    
    local requires
    requires=$(_get_requires "$module")
    
    for dep in $requires; do
        if [[ -f "${BOOTSTRAP_DIR}/modules/${dep}.sh" ]]; then
            deps_tree "$dep" $((indent + 2)) "$visited"
        else
            printf "%${indent}s%s (missing)\n" "" "$dep"
        fi
    done
}

# =============================================================================
# Category Info (Non-blocking)
# =============================================================================

# Show info about selected modules with same category prefix
# This is informational only - does not block installation
deps_show_category_info() {
    local selected=("$@")
    local -A categories
    
    for mod in "${selected[@]}"; do
        # Extract category (prefix before first dash)
        local category="${mod%%-*}"
        # If no dash, skip (atomic name)
        [[ "$category" == "$mod" ]] && continue
        categories["$category"]+=" $mod"
    done
    
    local first=true
    for cat in "${!categories[@]}"; do
        local count
        count=$(echo "${categories[$cat]}" | wc -w)
        if [[ $count -gt 1 ]]; then
            [[ "$first" == "true" ]] && echo "" && first=false
            log_warn "Multiple $cat modules selected:${categories[$cat]}"
        fi
    done
}
