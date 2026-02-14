#!/bin/bash
# =============================================================================
# Config Management Library
# =============================================================================
# File system primitives for dotfiles integration
# Works with any dotfiles manager: chezmoi, home-manager, git, etc.
# =============================================================================

# Configuration directories
CONFIG_DOTFILES_DIR="${HOME}/.dotfiles"
CONFIG_BACKUP_DIR="${HOME}/.dotfiles/backups"

# =============================================================================
# Directory Operations
# =============================================================================

# Ensure directory exists
# Usage: config_ensure_dir "/path/to/dir"
config_ensure_dir() {
    local dir="$1"
    if [[ -n "$dir" && ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# =============================================================================
# Existence Checks
# =============================================================================

# Check if file or directory exists
# Usage: config_exists "/path/to/file"
config_exists() {
    [[ -e "$1" ]]
}

# Check if path is a symlink
# Usage: config_is_link "/path/to/link"
config_is_link() {
    [[ -L "$1" ]]
}

# Check if path is a directory
# Usage: config_is_dir "/path/to/dir"
config_is_dir() {
    [[ -d "$1" ]]
}

# =============================================================================
# Symlink Operations
# =============================================================================

# Create symlink: source → target
# Usage: config_link "source" "target"
# Handles existing files by backing them up
config_link() {
    local source="$1"
    local target="$2"
    
    # Expand ~ to $HOME
    source="${source/#\~/$HOME}"
    target="${target/#\~/$HOME}"
    
    # Check source exists
    if [[ ! -e "$source" ]]; then
        echo "Error: Source does not exist: $source"
        return 1
    fi
    
    # Target exists and is not a link → backup
    if [[ -e "$target" && ! -L "$target" ]]; then
        config_backup "$target"
    fi
    
    # Remove existing link or file
    rm -f "$target"
    
    # Ensure target directory exists
    config_ensure_dir "$(dirname "$target")"
    
    # Create symlink
    ln -s "$source" "$target"
    echo "Linked: $target → $source"
}

# Link entire directory: source_dir → target_dir
# Usage: config_link_dir "source_dir" "target_dir"
config_link_dir() {
    local source="$1"
    local target="$2"
    
    source="${source/#\~/$HOME}"
    target="${target/#\~/$HOME}"
    
    # Check source exists
    if [[ ! -e "$source" ]]; then
        echo "Error: Source does not exist: $source"
        return 1
    fi
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Source is not a directory: $source"
        return 1
    fi
    
    # Target directory exists and is not a link → backup
    if [[ -e "$target" && ! -L "$target" ]]; then
        config_backup "$target"
    fi
    
    # Remove existing link or directory
    rm -rf "$target"
    
    # Ensure parent directory exists
    config_ensure_dir "$(dirname "$target")"
    
    # Create symlink
    ln -s "$source" "$target"
    echo "Linked: $target → $source"
}

# =============================================================================
# Copy Operations (for chezmoi-like managers)
# =============================================================================

# Copy file: source → target
# Usage: config_copy "source" "target"
config_copy() {
    local source="$1"
    local target="$2"
    
    source="${source/#\~/$HOME}"
    target="${target/#\~/$HOME}"
    
    # Check source exists
    if [[ ! -e "$source" ]]; then
        echo "Error: Source does not exist: $source"
        return 1
    fi
    
    # Target exists → backup
    if [[ -e "$target" ]]; then
        config_backup "$target"
    fi
    
    # Ensure target directory exists
    config_ensure_dir "$(dirname "$target")"
    
    # Copy file
    cp -r "$source" "$target"
    echo "Copied: $source → $target"
}

# Copy entire directory
# Usage: config_copy_dir "source_dir" "target_dir"
config_copy_dir() {
    local source="$1"
    local target="$2"
    
    source="${source/#\~/$HOME}"
    target="${target/#\~/$HOME}"
    
    # Check source exists
    if [[ ! -e "$source" ]]; then
        echo "Error: Source does not exist: $source"
        return 1
    fi
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Source is not a directory: $source"
        return 1
    fi
    
    # Target exists → backup
    if [[ -e "$target" ]]; then
        config_backup "$target"
    fi
    
    # Ensure parent directory exists
    config_ensure_dir "$(dirname "$target")"
    
    # Copy directory
    cp -r "$source" "$target"
    echo "Copied: $source → $target"
}

# =============================================================================
# Backup Operations
# =============================================================================

# Backup file or directory
# Usage: config_backup "/path/to/file" [backup_dir]
config_backup() {
    local path="$1"
    local backup_dir="${2:-$CONFIG_BACKUP_DIR}"
    
    path="${path/#\~/$HOME}"
    
    # Check path exists
    if [[ ! -e "$path" ]]; then
        return 1
    fi
    
    # Ensure backup directory
    config_ensure_dir "$backup_dir"
    
    # Generate backup name with timestamp
    local name
    name=$(basename "$path")
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${backup_dir}/${name}.${timestamp}"
    
    # Copy to backup
    cp -a "$path" "$backup_path"
    echo "Backed up: $path → $backup_path"
}

# =============================================================================
# Remove Operations
# =============================================================================

# Remove symlink or file (not directory)
# Usage: config_unlink "/path/to/link"
config_unlink() {
    local path="$1"
    
    path="${path/#\~/$HOME}"
    
    if [[ -L "$path" ]]; then
        rm "$path"
        echo "Removed link: $path"
    elif [[ -f "$path" ]]; then
        rm "$path"
        echo "Removed file: $path"
    fi
}

# =============================================================================
# Portable Config Discovery
# =============================================================================

# Find user config in portable locations
# Usage: config_find "module-name"
# Searches:
#   - ~/.dotfiles/<name>           (git dotfiles)
#   - ~/.config/<name>             (existing config)
#   - ~/.config/chezmoi/home_<name> (chezmoi source)
#   - ~/.config/bootstrap/overrides/<name> (bootstrap override)
# Returns first found path
config_find() {
    local name="$1"
    
    local search_paths=(
        "${HOME}/.dotfiles/${name}"
        "${HOME}/.config/${name}"
        "${HOME}/.config/chezmoi/home_${name}"
        "${HOME}/.config/bootstrap/overrides/${name}"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -e "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Find user config file (single file, not directory)
# Usage: config_find_file "module-name" "filename"
config_find_file() {
    local name="$1"
    local filename="$2"
    
    local search_paths=(
        "${HOME}/.dotfiles/${name}/${filename}"
        "${HOME}/.config/${name}/${filename}"
        "${HOME}/.config/chezmoi/home_${filename}"
        "${HOME}/.config/bootstrap/overrides/${name}/${filename}"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -e "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# Bootstrap Config
# =============================================================================

# Load bootstrap configuration
# Usage: config_load
# Looks for:
#   - ~/.config/bootstrap.conf
#   - ~/.config/bootstrap/bootstrap.conf
#   - ~/.config/bootstrap.yaml
config_load() {
    local config_files=(
        "${HOME}/.config/bootstrap.conf"
        "${HOME}/.config/bootstrap/bootstrap.conf"
        "${HOME}/.config/bootstrap.yaml"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            source "$file"
            echo "Loaded config: $file"
            return 0
        fi
    done
    
    return 1
}

# Get list of modules to install
# Usage: config_get_modules
# Returns module names from BOOTSTRAP_MODULES env var
config_get_modules() {
    echo "${BOOTSTRAP_MODULES:-}"
}

# Initialize dotfiles directory
config_init_dotfiles() {
    config_ensure_dir "$CONFIG_DOTFILES_DIR"
    config_ensure_dir "$HOME/.config"
    
    if [[ ! -d "$CONFIG_DOTFILES_DIR/.git" ]]; then
        git init "$CONFIG_DOTFILES_DIR" 2>/dev/null || true
    fi
    
    echo "Initialized dotfiles: $CONFIG_DOTFILES_DIR"
}

# Link config to dotfiles (legacy function)
# Usage: config_link_to_dotfiles "~/.config/dunst/dunstrc"
config_link_to_dotfiles() {
    local target_path="$1"
    target_path="${target_path/#\~/$HOME}"
    
    local rel_path
    if [[ "$target_path" == "$HOME"* ]]; then
        rel_path=".${target_path#$HOME}"
    else
        rel_path="$target_path"
    fi
    
    local dotfiles_target="$CONFIG_DOTFILES_DIR/$rel_path"
    local dotfiles_dir="$(dirname "$dotfiles_target")"
    
    config_ensure_dir "$dotfiles_dir"
    
    # Move existing file to dotfiles
    if [[ -f "$target_path" && ! -L "$target_path" ]]; then
        mv "$target_path" "$dotfiles_target"
        echo "Moved to dotfiles: $target_path -> $dotfiles_target"
    fi
    
    # Create symlink
    if [[ -e "$target_path" ]]; then
        rm -rf "$target_path"
    fi
    ln -s "$dotfiles_target" "$target_path"
    
    echo "Linked: $target_path -> $dotfiles_target"
}

# =============================================================================
# Autostart
# =============================================================================

# Add command to autostart
# Usage: autostart_add "command" [args...]
autostart_add() {
    local cmd="$1"
    shift
    local args="$@"
    
    local autostart_dir="$HOME/.config/autostart"
    local autostart_file="$autostart_dir/${cmd}.desktop"
    
    config_ensure_dir "$autostart_dir"
    
    # Skip if already exists
    if [[ -f "$autostart_file" ]]; then
        echo "Autostart already exists: $cmd"
        return 0
    fi
    
    # Create .desktop file
    cat > "$autostart_file" <<EOF
[Desktop Entry]
Type=Application
Name=$cmd
Exec=$cmd $args
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    echo "Added autostart: $cmd"
}

# Check if autostart entry exists
# Usage: autostart_exists "command"
autostart_exists() {
    local cmd="$1"
    [[ -f "$HOME/.config/autostart/${cmd}.desktop" ]]
}

# Remove autostart entry
# Usage: autostart_remove "command"
autostart_remove() {
    local cmd="$1"
    local autostart_file="$HOME/.config/autostart/${cmd}.desktop"
    
    if [[ -f "$autostart_file" ]]; then
        rm "$autostart_file"
        echo "Removed autostart: $cmd"
    fi
}

# =============================================================================
# Status
# =============================================================================

# Show config status
config_status() {
    echo "=== Config Status ==="
    echo "Dotfiles:     $CONFIG_DOTFILES_DIR"
    echo "Backup dir:   $CONFIG_BACKUP_DIR"
    echo "Config files: ~/.config/bootstrap.conf"
}
