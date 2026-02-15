#!/bin/bash
# =============================================================================
# Bootstrap Runner
# =============================================================================
# Main entry point for the composable Linux bootstrap framework
# =============================================================================

set -e

# Determine bootstrap directory
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core libraries
source "${BOOTSTRAP_DIR}/lib/log.sh"
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/deps.sh"
source "${BOOTSTRAP_DIR}/lib/state.sh"
source "${BOOTSTRAP_DIR}/lib/core.sh"

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat <<EOF
Bootstrap - Composable Linux Bootstrap Framework

Usage: bootstrap <command> [options]

Commands:
    install <module>     Install module(s) with dependency resolution
    deps <module>       Show dependency tree for module
    verify [module]     Verify installed module(s)
    proof <module>      Run proof checks for module
    
    status              Show bootstrap status
    reset               Reset state (force re-install)
    help                Show this help

Environment:
    BOOTSTRAP_DIR       Bootstrap installation directory
    TARGET_ROOT         Target system root (default: /)
    TARGET_USER         Target user (default: current user)

Examples:
    bootstrap install sway
    bootstrap deps sway
    bootstrap verify
    bootstrap status

EOF
}

# =============================================================================
# Commands
# =============================================================================

cmd_install() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        log_error "Module name required"
        echo "Usage: bootstrap install <module>"
        exit 1
    fi
    
    local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module"
        echo "Available modules:"
        ls -1 "${BOOTSTRAP_DIR}/modules/" 2>/dev/null || echo "  (none)"
        exit 1
    fi
    
    # Resolve dependencies
    log_info "Resolving dependencies for: $module"
    local -a ordered
    for m in $(deps_resolve "$module" 2>/dev/null); do
        ordered+=("$m")
    done
    
    log_info "Install order: ${ordered[*]}"
    echo ""
    
    # Show category info (non-blocking warning for conflicting modules)
    deps_show_category_info "${ordered[@]}"
    echo ""
    
    # Install each module in order
    for mod in "${ordered[@]}"; do
        if state_is_installed "$mod"; then
            log_info "Skipping $mod (already installed)"
            continue
        fi
        
        log_info "Installing: $mod"
        load_module "$mod"
        
        if install_module "$mod"; then
            state_set "$mod" "installed"
            log_success "$mod installed"
        else
            state_set "$mod" "failed"
            log_fail "$mod failed"
            exit 1
        fi
        echo ""
    done
    
    state_touch
    log_success "Bootstrap complete!"
}

cmd_verify() {
    local module="$1"
    
    proof_init
    
    if [[ -n "$module" ]]; then
        # Verify specific module
        local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
        
        if [[ ! -f "$module_file" ]]; then
            log_error "Module not found: $module"
            exit 1
        fi
        
        source "$module_file"
        
        if declare -f "module_verify" >/dev/null; then
            log_info "Verifying: $module"
            module_verify
        else
            log_warn "No verify function for: $module"
        fi
    else
        # Verify all modules
        log_info "Verifying all modules..."
        
        for mod_file in "${BOOTSTRAP_DIR}"modules/*.sh; do
            [[ -f "$mod_file" ]] || continue
            local mod_name
            mod_name=$(basename "$mod_file" .sh)
            
            source "$mod_file"
            
            if declare -f "module_verify" >/dev/null; then
                echo ""
                echo "=== $mod_name ==="
                module_verify
            fi
        done
    fi
    
    proof_report
}

cmd_proof() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        log_error "Module name required"
        echo "Usage: bootstrap proof <module>"
        exit 1
    fi
    
    proof_init
    
    local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module"
        exit 1
    fi
    
    source "$module_file"
    
    if declare -f "module_proofs" >/dev/null; then
        module_proofs
    else
        log_info "Running default proof checks..."
        proof_check "$module"
    fi
}

cmd_chain() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        log_error "Module name required"
        echo "Usage: bootstrap chain <module>"
        exit 1
    fi
    
    # Define dependency chain for common modules
    case "$module" in
        bluetooth-stack)
            proof_verify_chain "bluetooth-stack" "dbus" "init"
            ;;
        network-manager)
            proof_verify_chain "network-manager" "dbus" "init"
            ;;
        audio-pipewire)
            proof_verify_chain "audio-pipewire" "dbus" "alsa"
            ;;
        dunst)
            proof_verify_chain "dunst" "dbus" "x11-server"
            ;;
        *)
            log_error "Unknown module for chain: $module"
            log_info "Supported: bluetooth-stack, network-manager, audio-pipewire, dunst"
            exit 1
            ;;
    esac
}

cmd_template() {
    local name="$1"
    local dest="${2:-}"
    
    if [[ -z "$name" ]]; then
        log_info "Available templates:"
        ls -1 "${BOOTSTRAP_DIR}/templates/" 2>/dev/null || log_info "  (none)"
        exit 0
    fi
    
    # Set default placeholders
    config_set_placeholder "USER_NAME" "$USER"
    config_set_placeholder "HOME_DIR" "$HOME"
    
    if [[ -z "$dest" ]]; then
        dest="${HOME}/.config/${name}/config"
        mkdir -p "$(dirname "$dest")"
    fi
    
    log_info "Rendering template: $name"
    log_info "  From: ${BOOTSTRAP_DIR}/templates/${name}/config"
    log_info "  To: $dest"
    
    config_render_template "${name}/config" "$dest"
}

cmd_dotfiles() {
    local action="$1"
    
    case "$action" in
        init)
            config_init_dotfiles
            ;;
        link)
            local target="$2"
            if [[ -z "$target" ]]; then
                log_error "Usage: bootstrap dotfiles link <file>"
                exit 1
            fi
            config_link_to_dotfiles "$target"
            ;;
        status)
            log_info "=== Dotfiles Status ==="
            log_info "Dotfiles dir: $CONFIG_DOTFILES_DIR"
            echo ""
            if [[ -d "$CONFIG_DOTFILES_DIR" ]]; then
                log_info "Files in dotfiles:"
                find "$CONFIG_DOTFILES_DIR" -type f | head -20
            fi
            ;;
        *)
            log_error "Usage: bootstrap dotfiles <init|link|status>"
            exit 1
            ;;
    esac
}

cmd_status() {
    bootstrap_status
}

cmd_reset() {
    proof_reset
    state_clear
    log_info "State reset"
}

cmd_deps() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        log_error "Module name required"
        echo "Usage: bootstrap deps <module>"
        exit 1
    fi
    
    local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module"
        exit 1
    fi
    
    log_info "Dependency tree for: $module"
    echo ""
    deps_tree "$module"
    
    echo ""
    log_info "Install order:"
    for m in $(deps_resolve "$module" 2>/dev/null); do
        log_info "  $m"
    done
}

# =============================================================================
# Main
# =============================================================================

# Parse command
CMD="${1:-help}"
shift || true

case "$CMD" in
    install)
        cmd_install "$@"
        ;;
    deps)
        cmd_deps "$@"
        ;;
    verify)
        cmd_verify "$@"
        ;;
    proof)
        cmd_proof "$@"
        ;;
    chain)
        cmd_chain "$@"
        ;;
    template)
        cmd_template "$@"
        ;;
    dotfiles)
        cmd_dotfiles "$@"
        ;;
    status)
        cmd_status
        ;;
    reset)
        cmd_reset
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $CMD"
        usage
        exit 1
        ;;
esac
