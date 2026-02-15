# Package Manager Detection Improvement Plan

## Objective
Improve installation functionality by detecting the package manager directly instead of relying on distro detection. This provides better adaptability across distributions that share the same package manager.

## Current Architecture

```
distro_detect() → determines distro (debian, arch, fedora, etc.)
     ↓
pkg_install() → uses distro to select package manager
     ↓
case "$distro" in (apt, pacman, dnf, etc.)
```

## Proposed Architecture

```
pkgmgr_detect() → detects package manager directly (apt, pacman, dnf, etc.)
     ↓
pkg_install() → uses pkgmgr to execute installation
     ↓
case "$pkgmgr" in (apt, pacman, dnf, etc.)
```

## Key Changes

### 1. New Package Manager Detection Function

```bash
# Detect package manager directly
pkgmgr_detect() {
    local pkgmgr=""
    
    # Check for package manager commands (in order of preference)
    command -v pacman >/dev/null && pkgmgr="pacman"
    command -v apt    >/dev/null && pkgmgr="apt"
    command -v dnf    >/dev/null && pkgmgr="dnf"
    command -v zypper >/dev/null && pkgmgr="zypper"
    command -v apk    >/dev/null && pkgmgr="apk"
    command -v xbps-install >/dev/null && pkgmgr="xbps"
    command -v emerge >/dev/null && pkgmgr="emerge"
    
    if [[ -z "$pkgmgr" ]]; then
        echo "ERROR: Cannot detect package manager" >&2
        return 1
    fi
    
    echo "$pkgmgr"
}
```

### 2. Module Package Mapping Structure

**Before (distro-based):**
```bash
declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="hyprland"
MODULE_PACKAGES[debian]="hyprland"
MODULE_PACKAGES[ubuntu]="hyprland"
```

**After (pkgmgr-based):**
```bash
declare -A MODULE_PACKAGES
MODULE_PACKAGES[pacman]="hyprland"
MODULE_PACKAGES[apt]="hyprland"
MODULE_PACKAGES[dnf]="hyprland"
MODULE_PACKAGES[zypper]="hyprland"
MODULE_PACKAGES[apk]="hyprland"
MODULE_PACKAGES[xbps]="hyprland"
MODULE_PACKAGES[emerge]="hyprland"
```

### 3. Fallback Behavior

- **Fail-fast**: If package manager cannot be detected, the system will fail with an error
- No automatic fallback to distro detection (as per requirement)
- Manual override via `BOOTSTRAP_PKGMGR` environment variable for special cases

## Supported Package Managers

| Package Manager | Distributions | Commands |
|-----------------|---------------|----------|
| apt | Debian, Ubuntu, Mint | apt install, apt remove |
| pacman | Arch, Manjaro, EndeavourOS | pacman -S, pacman -R |
| dnf | Fedora, RHEL, CentOS | dnf install, dnf remove |
| zypper | openSUSE | zypper install, zypper remove |
| apk | Alpine | apk add, apk del |
| xbps | Void | xbps-install, xbps-remove |
| emerge | Gentoo | emerge |

## Module Update Pattern

Modules need to change from:
```bash
local distro
distro=$(distro_detect)
local packages="${MODULE_PACKAGES[$distro]}"
```

To:
```bash
local pkgmgr
pkgmgr=$(pkgmgr_detect)
local packages="${MODULE_PACKAGES[$pkgmgr]}"
```

## Implementation Order

1. Add `pkgmgr_detect()` and `pkgmgr_name()` to distro.sh
2. Update all `pkg_*` functions to use pkgmgr detection
3. Add pkgmgr-specific helper functions
4. Update module template/functions to use pkgmgr
5. Update existing modules
6. Update documentation

## Benefits

1. **Simpler mapping**: One package manager can serve multiple distros
2. **Better derivatives support**: Works with any distro using supported package managers
3. **Clearer semantics**: Package installation is directly tied to the tool that does the work
4. **Fail-fast validation**: Clearly identifies when system cannot be managed
