# Documentation vs Implementation Consistency Report

## Executive Summary

This report analyzes the consistency and correctness between the documentation in `docs/` and the actual implementation in `bootstrap/lib/` and `bootstrap/modules/`. Multiple inconsistencies were identified across function naming, configuration paths, variable names, and missing functionality.

---

## Critical Issues

### 1. Proof Function Naming Inconsistency (BUG)

**Location:** [`bootstrap/lib/core.sh:74`](bootstrap/lib/core.sh:74)

**Issue:** The `install_module()` function looks for `module_prove()` (singular), but all documentation and actual modules use `module_proofs()` (plural).

```bash
# core.sh line 74 - BUG:
if declare -f "module_prove" >/dev/null; then

# Correct function name per docs and all modules:
if declare -f "module_proofs" >/dev/null; then
```

**Impact:** Pre-installation proof verification will never run because the function name is wrong.

---

### 2. Config Variable Naming Inconsistency

**Location:** [`docs/architecture.md:166`](docs/architecture.md:166), [`docs/guide.md:54`](docs/guide.md:54)

**Issue:** Documentation shows `MODULES=(...)` but the implementation expects `BOOTSTRAP_MODULES`.

```bash
# docs/guide.md shows:
MODULES=(
    "dbus"
    "sway"
)

# But config.sh expects (line 325):
BOOTSTRAP_MODULES
```

**Impact:** Users following the documentation will have their module configuration ignored.

---

## API/Function Naming Issues

### 3. Missing `deps_check` Function

**Location:** [`docs/api.md:87-88`](docs/api.md:87-88) vs [`bootstrap/lib/deps.sh:198`](bootstrap/lib/deps.sh:198)

**Issue:** Documentation mentions `deps_check` but implementation has `deps_satisfied`.

```bash
# docs/api.md:
deps_check "module"

# Actual implementation:
deps_satisfied()
```

---

### 4. Missing `config_status` Documentation

**Location:** [`docs/api.md`](docs/api.md) missing documentation for `config_status`

**Issue:** `config.sh` defines `config_status()` (line 433) but it's not documented in api.md, although it's mentioned in architecture.md as "Show config status".

**Status:** Documented in architecture.md but not in api.md (incomplete).

---

## Configuration Path Issues

### 5. State File Path Inconsistency

**Location:** [`docs/api.md:95`](docs/api.md:95) vs [`bootstrap/lib/state.sh:11`](bootstrap/lib/state.sh:11)

**Issue:** Documentation says `bootstrap.state.json` but implementation uses `state.json`.

```bash
# docs/api.md:
# Load state from bootstrap.state.json

# Actual implementation:
STATE_FILE="${HOME}/.config/bootstrap/state.json"
```

---

### 6. Config File Search Path

**Location:** [`docs/api.md`](docs/api.md) vs [`bootstrap/lib/config.sh:303-318`](bootstrap/lib/config.sh:303-318)

**Issue:** Documentation only mentions `bootstrap.conf` but `config_load()` searches for multiple locations.

```bash
# docs/api.md:
config_load
# Load bootstrap.conf

# Actual config_load() searches:
~/.config/bootstrap.conf
~/.config/bootstrap/bootstrap.conf
~/.config/bootstrap.yaml
```

---

### 7. Config Directory Location

**Location:** [`docs/architecture.md:38`](docs/architecture.md:38) vs actual

**Issue:** Documentation says "Portable Config: bootstrap.conf stored in user's dotfiles" but doesn't specify exact path.

**Status:** Implementation uses `~/.config/` which is reasonable but undocumented.

---

## CLI Command Issues

### 8. Inconsistent CLI Invocation Examples

**Location:** [`docs/guide.md:166`](docs/guide.md:166) vs [`docs/architecture.md:187`](docs/architecture.md:187)

**Issue:** Guide shows `bootstrap install` while architecture shows `./bootstrap.sh install`.

```bash
# guide.md line 166:
bootstrap install

# architecture.md line 187:
./bootstrap.sh install
```

**Note:** The actual CLI is `./bootstrap.sh` from the project root.

---

## Module Function Issues

### 9. Module Verification Function Naming

**Location:** [`bootstrap/lib/core.sh:175`](bootstrap/lib/core.sh:175) vs [`bootstrap/lib/core.sh:74`](bootstrap/lib/core.sh:74)

**Issue:** Inconsistent function name checks within the same file.

```bash
# In install_module() - checks for "module_prove" (singular):
if declare -f "module_prove" >/dev/null; then

# In cmd_proof() - checks for "module_proofs" (plural):
if declare -f "module_proofs" >/dev/null; then
```

---

## Minor Issues

### 10. Module Template in docs vs Actual

**Location:** [`docs/modules.md:88`](docs/modules.md:88)

**Issue:** Template shows `module_verify()` but all modules use both `module_proofs()` and `module_verify()`.

```bash
# docs/modules.md shows:
module_install() { ... }
module_proofs() { ... }
module_verify() { ... }

# Actual modules have all three functions correctly defined
```

**Status:** Documentation is incomplete but not incorrect.

---

### 11. Missing Additional Proof Functions in Docs

**Location:** [`docs/api.md:110-116`](docs/api.md:110-116)

**Issue:** Proof functions documented but several implementation functions are missing:

| Documented | Missing from docs |
|------------|-------------------|
| `proof_command` | `proof_device` |
| `proof_process` | `proof_file_contains` |
| `proof_service_active` | `proof_user` |
| `proof_dbus_service` | `proof_user_in_group` |
| `proof_kernel_module` | `proof_network_interface` |
| `proof_file` | `proof_dns_resolve` |
| | `proof_port_listening` |
| | `proof_service_enabled` |

---

### 12. Missing Service Management Functions in Docs

**Location:** [`docs/api.md:127-131`](docs/api.md:127-131)

**Issue:** Some service functions missing from documentation:

| Documented | Missing from docs |
|------------|-------------------|
| `svc_enable` | `svc_restart` |
| `svc_start` | `svc_is_enabled` |
| `svc_stop` | `svc_is_active` |
| `svc_status` | |

---

## Summary of Fixes Required

| Priority | Issue | File to Fix |
|----------|-------|-------------|
| **Critical** | `module_prove` → `module_proofs` | [`bootstrap/lib/core.sh:74`](bootstrap/lib/core.sh:74) |
| **High** | `MODULES` → `BOOTSTRAP_MODULES` | [`docs/architecture.md`](docs/architecture.md), [`docs/guide.md`](docs/guide.md) |
| **Medium** | Add missing proof functions to docs | [`docs/api.md`](docs/api.md) |
| **Medium** | Add missing service functions to docs | [`docs/api.md`](docs/api.md) |
| **Medium** | Fix state file reference | [`docs/api.md:95`](docs/api.md) |
| **Low** | Add config search paths to docs | [`docs/api.md`](docs/api.md) |
| **Low** | Normalize CLI invocation examples | [`docs/guide.md`](docs/guide.md) |

---

## Additional Issue: Module Naming Inconsistency

### Problem

The module naming is inconsistent - some use category prefixes, others are flat/atomic:

| Pattern | Examples |
|---------|----------|
| **category-prefix** | `audio-pipewire`, `audio-pulseaudio`, `gpu-intel`, `network-manager`, `x11-server`, `bluetooth-stack` |
| **flat/atomic** | `dbus`, `sway`, `i3`, `hyprland`, `wofi`, `kitty`, `foot` |
| **hybrid** | `clipman`, `waybar`, `wl-paste`, `wireplumber` (could be `wl-clipman`, `wl-waybar`) |
| **X tools** | `xclip`, `xsel` (no prefix but X11-related) |

### Impact

1. **No category enforcement** - User can install conflicting modules (e.g., both `audio-pipewire` and `audio-pulseaudio`)
2. **Hard to discover related modules** - No clear grouping for users
3. **Inconsistent dependency checking** - Can't easily validate mutual exclusivity
4. **Error-prone** - No built-in validation for conflicting module selection

### Recommendation: Implement Category System

Add optional validation in dependency resolution:

```bash
# Define category prefixes that REQUIRE explicit prefix (user-specified)
CATEGORY_PREFIX_REQUIRED=(
    "audio"      # audio-pipewire, audio-pulseaudio, audio-alsa
    "gpu"        # gpu-intel, gpu-amd, gpu-nvidia
    "x11"        # x11-server
    "wayland"    # wayland
)

# Show info/warning instead of blocking
_check_category_prefix() {
    local module="$1"
    for cat in "${CATEGORY_PREFIX_REQUIRED[@]}"; do
        if [[ "$module" == "$cat"-* ]]; then
            return 0  # Has prefix, good
        fi
        if [[ "$module" == "$cat" ]]; then
            echo "Info: '$module' should be named '$cat-<variant>' (e.g., '$cat-pipewire')"
            return 0
        fi
    done
    return 0
}
```

This approach:
- **Non-blocking** - Shows info instead of errors
- **User-controlled** - Only warns for categories where prefix makes sense
- **Documentation** - Helps users understand naming conventions
- **Flexible** - Allows both `clipman` and `wl-clipman` patterns

### Recommendation: Show Conflicting Module Info

Instead of blocking, show warnings:

```bash
# Show info about selected modules with same category
_show_category_info() {
    local selected=("$@")
    local -A categories
    
    for mod in "${selected[@]}"; do
        local category="${mod%%-*}"
        [[ "$category" == "$mod" ]] && continue  # No prefix
        categories["$category"]+=" $mod"
    done
    
    for cat in "${!categories[@]}"; do
        echo "Note: Multiple $cat modules selected:${categories[$cat]}"
    done
}
```

This outputs something like:
```
Note: Multiple audio modules selected: audio-pipewire audio-pulseaudio
Note: Multiple gpu modules selected: gpu-intel
```

### Recommendation: Standardize Naming (Optional)

Adopt consistent naming convention for NEW modules:

```
# Recommended prefixes for clarity:
audio-*     # audio-pipewire, audio-pulseaudio
gpu-*       # gpu-intel, gpu-amd, gpu-nvidia
wl-*        # wl-clipman, wl-waybar (if Wayland-specific)
x11-*       # x11-server
network-*   # network-manager

# Atomic names OK for standalone tools:
dbus, sway, i3, hyprland, kitty, foot, wofi
```

---

## Code Quality Observations

### Positive Findings

1. **Module structure is consistent** - All modules follow the same pattern with `MODULE_NAME`, `MODULE_DESCRIPTION`, `MODULE_REQUIRES`, `MODULE_PROVIDES`, `MODULE_PACKAGES`, `module_install()`, `module_proofs()`, and `module_verify()`.

2. **Dependency resolution works correctly** - `deps.sh` implements proper topological sorting with cycle detection.

3. **Distro detection is comprehensive** - Supports Arch, Debian, Ubuntu, Fedora, openSUSE, Alpine, Void, Gentoo, and derivatives.

4. **Service management covers multiple init systems** - systemd, OpenRC, runit, s6, and sysvinit.

### Additional Notes

- The implementation is generally well-structured and follows good bash practices
- Some functions like `proof_verify_chain()` in proof.sh have hardcoded module checks that could be made more generic
- The state management uses simple grep/sed for JSON parsing which is fragile but functional for the use case
