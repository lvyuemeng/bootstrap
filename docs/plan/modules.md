# Module Development Plan

Status tracking for bootstrap modules.

## Status Legend

| Symbol | Meaning |
|--------|---------|
| [ ] | Not started |
| [-] | In progress |
| [x] | Completed |

---

## Core Modules

### System Services

| Module | Description | Status |
|--------|-------------|--------|
| `dbus` | D-Bus system/message bus | [x] |
| `udev` | Device management | [x] |

---

## Hardware Modules

| Module | Description | Status |
|--------|-------------|--------|
| `network-manager` | Network connection management | [x] |
| `bluetooth-stack` | Bluetooth functionality | [x] |
| `audio-pipewire` | PipeWire audio server | [x] |
| `audio-alsa` | ALSA sound drivers | [x] |
| `audio-pulseaudio` | PulseAudio (legacy) | [x] |
| `gpu-intel` | Intel GPU drivers | [x] |
| `gpu-amd` | AMD GPU drivers | [x] |
| `gpu-nvidia` | NVIDIA GPU drivers | [x] |

---

## Display Modules

| Module | Description | Status |
|--------|-------------|--------|
| `x11-server` | X11 display server | [x] |

---

## Session Modules

| Module | Description | Status |
|--------|-------------|--------|
| `polkit` | Policy authentication | [x] |
| `login-manager` | Display manager | [x] |

---

## Desktop Modules

### Window Managers

| Module | Description | Status |
|--------|-------------|--------|
| `i3` | i3 window manager | [x] |
| `openbox` | Openbox window manager | [x] |

### Panels

| Module | Description | Status |
|--------|-------------|--------|
| `polybar` | Status bar (X11) | [x] |
| `waybar` | Status bar (Wayland) | [x] |

### Widgets

| Module | Description | Status |
|--------|-------------|--------|
| `dunst` | Notification daemon (X11) | [x] |
| `mako` | Notification daemon (Wayland) | [x] |
| `wofi` | Application launcher (Wayland) | [x] |

### Terminal Emulators

| Module | Description | Status |
|--------|-------------|--------|
| `kitty` | GPU-accelerated terminal | [x] |
| `foot` | Fast Wayland terminal | [x] |

---

## Wayland Dependencies

| Module | Description | Status |
|--------|-------------|--------|
| `wlroots` | Wayland compositor library | [x] |

## Wayland Compositors

| Module | Description | Status |
|--------|-------------|--------|
| `sway` | i3-compatible Wayland compositor | [x] |
| `hyprland` | Dynamic tiling compositor | [x] |
| `niri` | Scrollable-tiling compositor | [x] |
| `river` | Dynamic tiling compositor | [x] |
| `labwc` | Labwc window manager | [x] |

---

## Audio Interfaces

| Module | Description | Status |
|--------|-------------|--------|
| `pavucontrol` | PulseAudio volume control | [x] |
| `wireplumber` | PipeWire session manager | [x] |
| `qpwgraph` | PipeWire graph control | [x] |

---

## Clipboard Managers

| Module | Description | Status |
|--------|-------------|--------|
| `clipman` | Clipboard manager (Wayland) | [x] |
| `wl-paste` | Clipboard tools (Wayland) | [x] |
| `xclip` | Clipboard tools (X11) | [x] |
| `xsel` | Clipboard tools (X11) | [x] |

---

## Implementation Guidelines

### Using distro.sh Library

```bash
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# Detect system
distro=$(distro_detect)
init=$(init_detect)

# Install packages
pkg_install "package-name"

# Manage services
svc_enable "servicename"
svc_start "servicename"
```

### Module Template

```bash
#!/bin/bash
# Module: module-name

MODULE_NAME="module-name"
MODULE_DESCRIPTION="Description"

# Load libraries
source "${BOOTSTRAP_DIR}/lib/config.sh"
source "${BOOTSTRAP_DIR}/lib/proof.sh"
source "${BOOTSTRAP_DIR}/lib/distro.sh"

# Requirements & Provides
MODULE_REQUIRES=(...)
MODULE_PROVIDES=(...)

# Package mapping (per distro)
declare -A MODULE_PACKAGES
MODULE_PACKAGES[arch]="..."
MODULE_PACKAGES[debian]="..."

# Module functions
module_install() { ... }
module_proofs() { ... }
module_verify() { ... }
module_info() { ... }
```

### Proof Requirements

Each module should implement proof verification:
1. **Pre-install proof**: Verify requirements before installation
2. **Post-install proof**: Verify the module is working
3. **Bottom-to-top chain**: Prove dependencies work first
