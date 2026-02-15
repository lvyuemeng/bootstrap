# Design Defects Report

## Overview

This document outlines design defects identified in the bootstrap system architecture by analyzing the source code in [`bootstrap/lib/`](bootstrap/lib/) and [`bootstrap/modules/`](bootstrap/modules/).

---

## Defect Summary

| ID | Severity | Location | Description |
|----|----------|----------|-------------|
| DEFECT-1 | **HIGH** | [`deps.sh:143-145`](bootstrap/lib/deps.sh:143) | In-degree calculation bug in topological sort |
| DEFECT-2 | **MEDIUM** | [`deps.sh`](bootstrap/lib/deps.sh) | No validation for non-existent module dependencies |
| DEFECT-3 | **HIGH** | [`core.sh:126`](bootstrap/lib/core.sh:126) | bootstrap() doesn't use dependency resolution |
| DEFECT-4 | **HIGH** | [`core.sh:51`](bootstrap/lib/core.sh:51) | State not saved after module installation |
| DEFECT-5 | **MEDIUM** | [`state.sh:63`](bootstrap/lib/state.sh:63) | Fragile JSON parsing with grep/sed |
| DEFECT-6 | **MEDIUM** | [`modules/`](bootstrap/modules/) | Inconsistent package manager keys (pacman vs arch) |
| DEFECT-7 | **HIGH** | [`audio-pipewire.sh:22`](bootstrap/modules/audio-pipewire.sh:22) | Depends on non-existent "init" module |
| DEFECT-8 | **LOW** | [`bluetooth-stack.sh:35`](bootstrap/modules/bluetooth-stack.sh:35) | Missing distribution packages (fedora, opensuse) |
| DEFECT-9 | **LOW** | [`deps.sh`](bootstrap/lib/deps.sh) | Circular dependency detection incomplete |
| DEFECT-10 | **MEDIUM** | [`deps.sh`](bootstrap/lib/deps.sh) | Optional dependencies not properly handled |

---

## Detailed Defect Analysis

### DEFECT-1: In-degree Calculation Bug (HIGH)

**Location:** [`deps.sh:143-145`](bootstrap/lib/deps.sh:143)

**Issue:** The topological sort algorithm has incorrect in-degree calculation:

```bash
for module in "${all_modules[@]}"; do
    local requires
    requires=$(_get_requires "$module")
    
    for dep in $requires; do
        # BUG: Checks if DEP is in all_modules, should increment DEPENDENT's in-degree
        for m in "${all_modules[@]}"; do
            [[ "$m" == "$dep" ]] && ((in_degree["$module"]++))
        done
    done
done
```

**Problem:** This incorrectly checks if the dependency exists in `all_modules`, but should increment the in-degree of the **dependent module** (the one that requires something). This causes false circular dependency detection.

---

### DEFECT-2: No Module Validation (MEDIUM)

**Location:** [`deps.sh`](bootstrap/lib/deps.sh)

**Issue:** When a module specifies `MODULE_REQUIRES=("nonexistent-module")`, the system doesn't validate this at load time. The code at line 117 checks if the file exists but continues execution anyway.

---

### DEFECT-3: Bootstrap Doesn't Use Dependency Resolution (HIGH)

**Location:** [`core.sh:126`](bootstrap/lib/core.sh:126)

**Issue:** The `bootstrap()` function reads modules from config and installs them in file-order, not dependency order:

```bash
# From core.sh line 154-164
for mod in "${modules[@]}"; do
    load_module "$mod" || { ... }
    install_module "$mod" || { ... }
done
```

**Missing:** Should call `deps_resolve` first to get correct installation order.

---

### DEFECT-4: State Not Saved (HIGH)

**Location:** [`core.sh:51`](bootstrap/lib/core.sh:51)

**Issue:** The `install_module()` function doesn't call `state_set` or `state_save` to track installed modules. After installation, the system has no record of what was installed.

---

### DEFECT-5: Fragile JSON Parsing (MEDIUM)

**Location:** [`state.sh:63`](bootstrap/lib/state.sh:63)

**Issue:** Uses regex/grep/sed for JSON parsing which is error-prone:

```bash
value=$(echo "$state" | grep -o "\"$module\": *{[^}]*}" | sed "s/.*\"installed\": *\([^,}]*\).*/\1/" | tr -d ' ')
```

**Problems:**
- Doesn't handle nested JSON
- Breaks if module name is substring of another module name
- Doesn't handle special characters in values

---

### DEFECT-6: Inconsistent Package Keys (MEDIUM)

**Location:** Multiple modules

**Issue:** Architecture specifies "Distribution-specific packages" but modules use inconsistent keys:

- [`sway.sh:40`](bootstrap/modules/sway.sh:40): Uses `MODULE_PACKAGES[pacman]` (package manager)
- [`dbus.sh:35`](bootstrap/modules/dbus.sh:35): Uses `MODULE_PACKAGES[arch]` (distribution)

---

### DEFECT-7: Invalid Dependency (HIGH)

**Location:** [`audio-pipewire.sh:22`](bootstrap/modules/audio-pipewire.sh:22)

**Issue:** Specifies `MODULE_REQUIRES=("init")` but no `init.sh` module exists.

---

### DEFECT-8: Missing Distribution Packages (LOW)

**Location:** [`bluetooth-stack.sh:35`](bootstrap/modules/bluetooth-stack.sh:35)

**Issue:** `MODULE_PACKAGES` only defines: arch, debian, alpine, gentoo, void

**Missing:** fedora, opensuse, ubuntu, fedora

---

### DEFECT-9: Incomplete Cycle Detection (LOW)

**Location:** [`deps.sh`](bootstrap/lib/deps.sh)

**Issue:** While `deps_tree` has cycle detection, `deps_resolve` only provides generic "Circular dependency detected" without identifying which modules form the cycle.

---

### DEFECT-10: Optional Dependencies Ignored (MEDIUM)

**Location:** [`deps.sh`](bootstrap/lib/deps.sh)

**Issue:** `MODULE_OPTIONAL` is read but never used in dependency resolution. The `deps_resolve` function only considers `MODULE_REQUIRES`.

---

## Test Coverage

Tests should verify:

1. ✅ Dependency resolution produces correct topological order
2. ✅ Non-existent module dependencies are caught
3. ✅ bootstrap() uses deps_resolve
4. ✅ State is saved after installation
5. ✅ JSON parsing handles edge cases
6. ✅ Package keys are consistent
7. ✅ All dependencies point to existing modules
8. ✅ All distributions have package definitions
9. ✅ Circular dependencies are detected with useful messages
10. ✅ Optional dependencies are properly handled

---

## Recommendations

1. **Fix in-degree calculation** in deps.sh - swap the logic to increment the dependent's in-degree
2. **Add module validation** - fail fast if MODULE_REQUIRES points to missing modules
3. **Integrate deps_resolve** into bootstrap() function
4. **Add state tracking** - call state_set in install_module()
5. **Use proper JSON library** - consider jq or a bash JSON parser
6. **Standardize package keys** - use distribution names consistently
7. **Validate dependencies** - ensure all required modules exist
8. **Complete distribution coverage** - add missing MODULE_PACKAGES entries
9. **Improve error messages** - show cycle path in errors
10. **Handle optional deps** - include in resolution with lower priority
