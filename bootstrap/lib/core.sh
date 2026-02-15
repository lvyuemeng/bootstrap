#!/bin/bash
# =============================================================================
# Bootstrap Core Library
# =============================================================================
# Provides the main bootstrap orchestration with config and proof integration
# =============================================================================

# Bootstrap root directory
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Target system root (empty for chroot/local, or specify for container/remote)
TARGET_ROOT="${TARGET_ROOT:-}"
TARGET_USER="${TARGET_USER:-$(whoami)}"

# Load dependencies
source "${BOOTSTRAP_DIR}/lib/log.sh"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/deps.sh"
source "${BOOTSTRAP_DIR}/lib/state.sh"

# =============================================================================
# Module System
# =============================================================================

# Module registry
declare -A MODULE_REGISTRY

# Load module definition
load_module() {
    local module_name="$1"
    local module_path="${2:-$BOOTSTRAP_DIR/modules}"
    
    local module_file="$module_path/${module_name}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module_name"
        return 1
    fi
    
    # Source module (get definitions without executing)
    source "$module_file"
    
    # Register
    MODULE_REGISTRY["$module_name"]="$module_file"
    
    log_info "Loaded module: $module_name"
}

# Install a module (with config rendering and proof verification)
install_module() {
    local module_name="$1"
    local module_file="${MODULE_REGISTRY[$module_name]}"
    
    if [[ -z "$module_file" ]]; then
        log_error "Module not registered: $module_name"
        return 1
    fi
    
    log_section "Installing module: $module_name"
    
    # Source module to get functions
    source "$module_file"
    
    # Check if module function exists
    if ! declare -f "module_install" >/dev/null; then
        log_error "Module $module_name has no install function"
        return 1
    fi
    
    # Run pre-install proof (verify requirements)
    if declare -f "module_proofs" >/dev/null; then
        log_info "Running proof verification..."
        module_proofs || {
            log_error "Proof failed for $module_name"
            return 1
        }
    fi
    
    # Install module
    module_install
    
    # Run post-install verification
    if declare -f "module_verify" >/dev/null; then
        log_info "Running post-install verification..."
        module_verify || {
            log_error "Verification failed for $module_name"
            return 1
        }
    fi
    
    log_info "Module $module_name installed successfully"
}

# =============================================================================
# Configuration Rendering (Templates Instead of Cat)
# =============================================================================

# Render module configs from templates
render_module_configs() {
    local module_name="$1"
    local configs_dir="$BOOTSTRAP_DIR/configs/$module_name"
    
    if [[ ! -d "$configs_dir" ]]; then
        log_debug "No configs directory for: $module_name"
        return 0
    fi
    
    log_info "Rendering configs for: $module_name"
    
    # Process each config template
    find "$configs_dir" -type f -name "*.conf" -o -name "*.ini" -o -name "*.cfg" | while read -r template; do
        local relative="${template#$configs_dir/}"
        local dest="$TARGET_ROOT/etc/$relative"
        
        # Render with placeholders
        config_render_template "$module_name/configs/$relative" "$dest"
    done
}

# =============================================================================
# Bootstrap Workflow
# =============================================================================

# Main bootstrap function
bootstrap() {
    local target_config="$1"  # Config file with module list
    
    log_section "Starting bootstrap"
    log_info "Bootstrap directory: $BOOTSTRAP_DIR"
    log_info "Target root: $TARGET_ROOT"
    echo ""
    
    # Initialize proof system
    proof_init
    
    # Load placeholders from config
    if [[ -n "$target_config" && -f "$target_config" ]]; then
        config_load_placeholders "$target_config"
    fi
    
    # Parse modules to install
    local -a modules
    if [[ -n "$target_config" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            modules+=("$line")
        done < "$target_config"
    fi
    
    echo "Modules to install: ${modules[*]}"
    echo ""
    
    # Install each module
    for mod in "${modules[@]}"; do
        load_module "$mod" || {
            log_error "Failed to load: $mod"
            continue
        }
        install_module "$mod" || {
            log_error "Failed to install: $mod"
            continue
        }
    done
    
    # Final proof report
    proof_report
}

# Quick verify all installed modules
bootstrap_verify() {
    log_info "Running verification for all modules..."
    proof_init
    
    for mod in "${!MODULE_REGISTRY[@]}"; do
        source "${MODULE_REGISTRY[$mod]}"
        
        if declare -f "module_verify" >/dev/null; then
            log_info "Verifying: $mod"
            module_verify || log_error "  ✗ Failed"
        fi
    done
    
    proof_report
}

# Show bootstrap status
bootstrap_status() {
    log_section "Bootstrap Status"
    log_info "Bootstrap Dir: $BOOTSTRAP_DIR"
    log_info "Target Root: $TARGET_ROOT"
    log_info "Target User: $TARGET_USER"
    echo ""
    config_status
    echo ""
    proof_report
}

# =============================================================================
# Module Template Helpers
# =============================================================================

# Define a module with config templates
# Usage: define_module "module_name" "description"
define_module() {
    local name="$1"
    local desc="$2"
    
    MODULE_NAME="$name"
    MODULE_DESCRIPTION="$desc"
    
    # Default install (calls config render + verify)
    module_install() {
        log_info "Installing $MODULE_NAME: $MODULE_DESCRIPTION"
        
        # Render configs if exist
        render_module_configs "$MODULE_NAME"
        
        # Show post-install info
        if declare -f "module_info" >/dev/null; then
            module_info
        fi
    }
    
    # Default verify (runs proof checks)
    module_verify() {
        log_info "Verifying $MODULE_NAME..."
        local result=0
        
        if declare -f "module_proofs" >/dev/null; then
            module_proofs || result=1
        fi
        
        return $result
    }
}

# Module requirement helper
require() {
    local req_type="$1"
    local req_value="$2"
    
    case "$req_type" in
        process)
            proof_process "$req_value" || return 1
            ;;
        service)
            proof_service_active "$req_value" || return 1
            ;;
        kernel-module)
            proof_kernel_module "$req_value" || return 1
            ;;
        dbus)
            proof_dbus_service "$req_value" || return 1
            ;;
        command)
            proof_command "$req_value" || return 1
            ;;
        file)
            proof_file "$req_value" || return 1
            ;;
        user)
            proof_user "$req_value" || return 1
            ;;
        *)
            log_error "Unknown requirement type: $req_type"
            return 1
            ;;
    esac
}

# Module provides helper
provides() {
    echo "Provides: $*"
}

# Export for use in modules
export -f define_module
export -f require
export -f provides
