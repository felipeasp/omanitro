# OmaNitro — Acer Nitro 5 Hardware Plugin for Omarchy

Native Quickshell/QML plugin for the **Omarchy Desktop Shell** designed for hardware telemetry and control on **Acer Nitro 5 (AN517-54)** and compatible Nitro/Predator laptops using the `linuwu_sense` kernel module and `envycontrol`.

**Plugin ID:** `io.github.felipeasp.omanitro`  
**Author:** Felipe Pires ([@felipeasp](https://github.com/felipeasp))  
**Repository:** [https://github.com/felipeasp/omanitro](https://github.com/felipeasp/omanitro)

---

## 🚀 Features

1. **Dynamic Hardware Detection:**
   - **Laptop Model:** Automatically queried from `/sys/class/dmi/id/product_name` (e.g. `Nitro AN517-54`).
   - **CPU Model:** Clean processor string parsed from `/proc/cpuinfo` (e.g. `11th Gen Intel Core i5-11400H`).
   - **Dedicated GPU Model:** Queried via `nvidia-smi` / `lspci` (e.g. `NVIDIA GeForce GTX 1650`).
   - No hardcoded hardware labels in UI or scripts.

2. **Minimalist Bar Widget (`BarWidget.qml`):**
   - Clean laptop icon (`󰌢`) on the taskbar pill.
   - Dynamic urgent/red color alert on CoolBoost (100% max fans).
   - Rich telemetry tooltip on hover:
     ```
     CPU: 62°C | GPU: 55°C
     PERFORMANCE • AUTO Fans
     ```
   - Click to open the dashboard panel; right-click to quick-cycle fan mode.

3. **Dashboard with Dual Circular Arc Gauges (`Panel.qml`):**
   - High-precision circular arc gauges rendered via HTML5/QML Canvas (135° to 405° track).
   - Live CPU fan RPM, GPU fan RPM, and sensor temperatures (`CPU`, `GPU`, and `Motherboard/Sys`).
   - Dark theme palette matching Omarchy design specifications (`#161925` background, `#282c3f` borders, `#8ea2d6` accent).

4. **4 ACPI Thermal & Power Profiles:**
   - Presets: `Quiet`, `Balanced`, `Balanced-Perf`, and `Performance`.
   - Synchronized with `powerprofilesctl` and `/sys/firmware/acpi/platform_profile`.

5. **Cooling & Fan Controls:**
   - `Auto` (BIOS controlled), `Max` (CoolBoost 100%), and `Custom`.
   - Responsive sliders for custom CPU & GPU speeds (0–100%) with apply action.

6. **Battery Care & USB Power-off Charging:**
   - 80% charge limiter (`battery_limiter`) to maximize battery lifespan.
   - Factory battery calibration trigger (`battery_calibration`).
   - USB Power-off Charging selector: `Off`, `10%`, `20%`, and `30%` cutoff thresholds.

7. **Hardware Tweaks (`linuwu_sense`):**
   - **LCD Overdrive:** 3ms response time acceleration toggle.
   - **Keyboard Backlight Timeout:** 30-second idle sleep toggle.
   - **BIOS Boot Sound & Animation:** Acer Predator/Nitro boot sound toggle.

8. **Hybrid Graphics Switching (EnvyControl):**
   - Seamless Optimus graphics mode selection (`hybrid`, `integrated`, `nvidia`).
   - Graceful status fallback when `envycontrol` is not installed.

9. **Polkit Passwordless Privileges (`io.github.felipeasp.omanitro.control`):**
   - Elevated operations in `/sys` and `envycontrol` handled safely via Polkit rules for users in the `wheel` group.

---

## 📁 Repository Structure

```
omanitro/
├── manifest.json                           # Plugin manifest (id: io.github.felipeasp.omanitro)
├── BarWidget.qml                           # Status bar pill component (icon-only + tooltip)
├── Panel.qml                               # Circular arc gauge dashboard panel
├── scripts/
│   ├── nitro-helper.sh                     # Hardware helper & telemetry backend
│   └── backend.sh                          # CLI wrapper
├── polkit/
│   ├── io.github.felipeasp.omanitro.policy # PolicyKit action definition
│   └── 50-io.github.felipeasp.omanitro.rules # Wheel group passwordless rule
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
omarchy omanitro profile set balanced-performance
omarchy omanitro profile set performance

# Battery care
omarchy omanitro battery limit on
omarchy omanitro battery limit off
omarchy omanitro battery limit status
omarchy omanitro battery calibrate start
omarchy omanitro battery calibrate stop

# USB power-off charging (0%, 10%, 20%, 30%)
omarchy omanitro usb set 30
omarchy omanitro usb status

# Hardware tweaks
omarchy omanitro tweaks lcd on
omarchy omanitro tweaks backlight on
omarchy omanitro tweaks bootsound off

# GPU switching (requires envycontrol)
omarchy omanitro gpu hybrid
omarchy omanitro gpu integrated
omarchy omanitro gpu nvidia
```

---

## 📄 License
GPL-3.0-or-later.
