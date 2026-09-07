# OmaNitro — Acer Nitro 5 Hardware Plugin for Omarchy

Native Quickshell/QML plugin for the **Omarchy Desktop Shell** designed for hardware telemetry and control on **Acer Nitro 5 (AN517-54)** and compatible Nitro/Predator laptops using the `linuwu_sense` kernel module and `envycontrol`.

**Plugin ID:** `io.github.felipeasp.omanitro`  
**Author:** Felipe Pires ([@felipeasp](https://github.com/felipeasp))  
**Repository:** [https://github.com/felipeasp/omanitro](https://github.com/felipeasp/omanitro)

---

## 🚀 Features

1. **Cooling & Fan Controls:**
   - Real-time CPU & GPU RPM sensors and thermal readings (`hwmon`).
   - Fan mode presets: `Auto` (BIOS controlled), `Max` (CoolBoost 100%), and `Custom`.
   - Responsive sliders for setting custom CPU & GPU speeds (0–100%).
2. **ACPI Power & Thermal Profiles:**
   - Switch between `Quiet`, `Balanced`, and `Performance` platform profiles.
   - Synchronized with `powerprofilesctl` and `/sys/firmware/acpi/platform_profile`.
3. **Battery Health Care:**
   - 80% charge limiter (`battery_limiter`) to maximize lifespan.
   - Factory battery calibration trigger (`battery_calibration`).
4. **Hybrid Graphics Switching (EnvyControl):**
   - Seamless Optimus graphics mode selection (`hybrid`, `integrated`, `nvidia`).
   - Graceful status fallback when `envycontrol` is not installed.
5. **Omarchy Bar Widget & Interactive Panel:**
   - Compact status bar pill displaying fan icon `󰈐` (highlighted on max), CPU/GPU temperatures, fan RPM, and `󰂄80%` battery badge.
   - Detailed dropdown card styled to match `omarchy.power` with PlainText typography.
6. **Polkit Passwordless Privileges (`io.github.felipeasp.omanitro.control`):**
   - Elevated operations in `/sys` and `envycontrol` handled safely via Polkit rules for users in the `wheel` group.

---

## 📁 Repository Structure

```
omanitro/
├── manifest.json                           # Plugin manifest (id: io.github.felipeasp.omanitro)
├── BarWidget.qml                           # Status bar pill component
├── Panel.qml                               # Dropdown hardware control panel
├── scripts/
│   ├── nitro-helper.sh                     # Hardware helper & telemetry backend
│   └── backend.sh                          # CLI / QML bridge wrapper
├── polkit/
│   ├── io.github.felipeasp.omanitro.policy # PolicyKit action definition
│   └── 50-io.github.felipeasp.omanitro.rules # Wheel group rule
├── bin/
│   └── omarchy-omanitro                    # Omarchy CLI integration binary
├── systemd/
│   └── omanitro.service                    # Systemd boot state restoration service
├── install.sh                              # Complete installer script
├── uninstall.sh                            # Uninstaller script
└── README.md                               # Documentation
```

---

## 🛠️ Installation

### 1. User Plugin Installation (Shell Only)
To install the widget to your user configuration (`~/.config/omarchy/plugins/io.github.felipeasp.omanitro/`):
```bash
./install.sh
```

### 2. Full System-Wide Installation (Polkit & System Services)
To install the privileged helper, Polkit policy (passwordless execution for `wheel`), and systemd persistence service:
```bash
sudo ./install.sh
```

### 3. Enable in Omarchy Shell
```bash
omarchy plugin enable io.github.felipeasp.omanitro --section right
omarchy restart shell
```

---

## 💻 CLI Commands

The plugin integrates into Omarchy's CLI under `omarchy omanitro`:

```bash
# View complete hardware telemetry
omarchy omanitro status

# Output telemetry in compact JSON (for scripts/conky/widgets)
omarchy omanitro status --json

# Fan management
omarchy omanitro fan auto
omarchy omanitro fan max
omarchy omanitro fan set 60 70

# ACPI platform profiles
omarchy omanitro profile set quiet
omarchy omanitro profile set balanced
omarchy omanitro profile set performance

# Battery health
omarchy omanitro battery limit on
omarchy omanitro battery limit off
omarchy omanitro battery limit status

# GPU switching (requires envycontrol)
omarchy omanitro gpu hybrid
omarchy omanitro gpu integrated
omarchy omanitro gpu nvidia
```

---

## 📄 License
GPL-3.0-or-later.
