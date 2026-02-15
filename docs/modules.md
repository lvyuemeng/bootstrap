# Modules

Status tracking for bootstrap modules.

## Philosophy

**Flat modules** - No folders, no categories. All modules in one directory.

```
modules/
├── dbus.sh
├── udev.sh
├── sway.sh
├── i3.sh
└── ...
```

Order is determined by MODULE_REQUIRES, not by folder structure.

---

## Module List

| Module | Description | Status |
|--------|-------------|--------|
| `dbus` | D-Bus system/message bus | [x] |
| `udev` | Device management | [x] |
| `network-manager` | Network connection management | [x] |
| `bluetooth-stack` | Bluetooth functionality | [x] |
| `audio-pipewire` | PipeWire audio server | [x] |
| `audio-alsa` | ALSA sound drivers | [x] |
| `audio-pulseaudio` | PulseAudio (legacy) | [x] |
| `gpu-intel` | Intel GPU drivers | [x] |
| `gpu-amd` | AMD GPU drivers | [x] |
| `gpu-nvidia` | NVIDIA GPU drivers | [x] |
| `x11-server` | X11 display server | [x] |
| `polkit` | Policy authentication | [x] |
| `login-manager` | Display manager | [x] |
| `i3` | i3 window manager | [x] |
| `openbox` | Openbox window manager | [x] |
| `sway` | i3-compatible Wayland compositor | [x] |
| `hyprland` | Dynamic tiling compositor | [x] |
| `niri` | Scrollable-tiling compositor | [x] |
| `river` | Dynamic tiling compositor | [x] |
| `labwc` | Labwc window manager | [x] |
| `wlroots` | Wayland compositor library | [x] |
| `polybar` | Status bar (X11) | [x] |
| `waybar` | Status bar (Wayland) | [x] |
| `dunst` | Notification daemon (X11) | [x] |
| `mako` | Notification daemon (Wayland) | [x] |
| `wofi` | Application launcher (Wayland) | [x] |
| `kitty` | GPU-accelerated terminal | [x] |
| `foot` | Fast Wayland terminal | [x] |
| `pavucontrol` | PulseAudio volume control | [x] |
| `wireplumber` | PipeWire session manager | [x] |
| `qpwgraph` | PipeWire graph control | [x] |
| `clipman` | Clipboard manager (Wayland) | [x] |
| `wl-paste` | Clipboard tools (Wayland) | [x] |
| `xclip` | Clipboard tools (X11) | [x] |
| `xsel` | Clipboard tools (X11) | [x] |

---

## Module Template

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
```

## Proof Requirements

Each module should implement proof verification:
1. **Pre-install proof**: Verify requirements before installation
2. **Post-install proof**: Verify the module is working
3. **Bottom-to-top chain**: Prove dependencies work first
