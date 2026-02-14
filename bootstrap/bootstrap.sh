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
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/core.sh"

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat <<EOF
Bootstrap - Composable Linux Bootstrap Framework

Usage: bootstrap <command> [options]

Commands:
    install <module>     Install a module with proof verification
    verify [module]       Verify installed module(s)
    proof <module>        Run proof checks for module
    chain <module>        Run bottom-to-top proof chain
    template <name>       Render a config template
    dotfiles <action>     Manage dotfiles integration
                         actions: init, link, status
    
    status                Show bootstrap status
    reset                 Reset proof state (force re-verification)
    help                  Show this help

Environment:
    BOOTSTRAP_DIR         Bootstrap installation directory
    TARGET_ROOT           Target system root (default: /)
    TARGET_USER           Target user (default: current user)
    BOOTSTRAP_LINK_DOTFILES   Link configs to dotfiles repo

Examples:
    bootstrap install dunst
    bootstrap proof bluetooth-stack
    bootstrap chain network-manager
    bootstrap dotfiles init
    bootstrap status

EOF
}

# =============================================================================
# Commands
# =============================================================================

cmd_install() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        echo "Error: Module name required"
        echo "Usage: bootstrap install <module>"
        exit 1
    fi
    
    local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        echo "Error: Module not found: $module"
        echo "Available modules:"
        ls -1 "${BOOTSTRAP_DIR}/modules/" 2>/dev/null || echo "  (none)"
        exit 1
    fi
    
    echo "Installing module: $module"
    load_module "$module"
    install_module "$module"
}

cmd_verify() {
    local module="$1"
    
    proof_init
    
    if [[ -n "$module" ]]; then
        # Verify specific module
        local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
        
        if [[ ! -f "$module_file" ]]; then
            echo "Error: Module not found: $module"
            exit 1
        fi
        
        source "$module_file"
        
        if declare -f "module_verify" >/dev/null; then
            echo "Verifying: $module"
            module_verify
        else
            echo "No verify function for: $module"
        fi
    else
        # Verify all modules
        echo "Verifying all modules..."
        
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
        echo "Error: Module name required"
        echo "Usage: bootstrap proof <module>"
        exit 1
    fi
    
    proof_init
    
    local module_file="${BOOTSTRAP_DIR}/modules/${module}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        echo "Error: Module not found: $module"
        exit 1
    fi
    
    source "$module_file"
    
    if declare -f "module_proofs" >/dev/null; then
        module_proofs
    else
        echo "Running default proof checks..."
        proof_check "$module"
    fi
}

cmd_chain() {
    local module="$1"
    
    if [[ -z "$module" ]]; then
        echo "Error: Module name required"
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
            echo "Unknown module for chain: $module"
            echo "Supported: bluetooth-stack, network-manager, audio-pipewire, dunst"
            exit 1
            ;;
    esac
}

cmd_template() {
    local name="$1"
    local dest="${2:-}"
    
    if [[ -z "$name" ]]; then
        echo "Available templates:"
        ls -1 "${BOOTSTRAP_DIR}/templates/" 2>/dev/null || echo "  (none)"
        exit 0
    fi
    
    # Set default placeholders
    config_set_placeholder "USER_NAME" "$USER"
    config_set_placeholder "HOME_DIR" "$HOME"
    
    if [[ -z "$dest" ]]; then
        dest="${HOME}/.config/${name}/config"
        mkdir -p "$(dirname "$dest")"
    fi
    
    echo "Rendering template: $name"
    echo "  From: ${BOOTSTRAP_DIR}/templates/${name}/config"
    echo "  To: $dest"
    
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
                echo "Usage: bootstrap dotfiles link <file>"
                exit 1
            fi
            config_link_to_dotfiles "$target"
            ;;
        status)
            echo "=== Dotfiles Status ==="
            echo "Dotfiles dir: $CONFIG_DOTFILES_DIR"
            echo ""
            if [[ -d "$CONFIG_DOTFILES_DIR" ]]; then
                echo "Files in dotfiles:"
                find "$CONFIG_DOTFILES_DIR" -type f | head -20
            fi
            ;;
        *)
            echo "Usage: bootstrap dotfiles <init|link|status>"
            exit 1
            ;;
    esac
}

cmd_status() {
    bootstrap_status
}

cmd_reset() {
    proof_reset
    echo "Proof state reset"
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
        echo "Unknown command: $CMD"
        usage
        exit 1
        ;;
esac
