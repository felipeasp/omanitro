# OmaNitro

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange.svg)]()
[![Omarchy Shell](https://img.shields.io/badge/Shell-Omarchy%20(Quickshell)-purple.svg)]()
[![Kernel Driver](https://img.shields.io/badge/Driver-linuwu__sense-success.svg)]()

**OmaNitro** (`io.github.felipeasp.omanitro`) is a native Quickshell/QML hardware monitoring and cooling control plugin for the **Omarchy Desktop Shell**, designed specifically for **Acer Nitro 5** (e.g. AN517-54, AN515-57) and compatible Acer Nitro/Predator laptops running the [`linuwu_sense`](https://github.com/0x1e-lab/linuwu-sense) kernel driver.

---

## ✨ Features

- **Dual Circular Arc Telemetry Gauges:** High-precision circular gauges rendered via HTML5/QML Canvas displaying live CPU and dedicated GPU fan speeds (RPM), accompanied by real-time thermal readings (`CPU`, `GPU`, and `Motherboard/System`).
- **Dynamic Hardware Detection:** Automatically extracts real laptop model (`/sys/class/dmi/id/product_name`), CPU model name (`/proc/cpuinfo`), and dedicated GPU model (`nvidia-smi` / `lspci`). Zero hardcoded device names.
- **4 ACPI Thermal & Power Profiles:** Seamlessly switch between `Quiet`, `Balanced`, `Balanced-Performance`, and `Performance` profiles, fully synchronized with `powerprofilesctl` and ACPI platform profiles.
- **Cooling & Fan Controls:**
  - `Auto`: Dynamic fan curve managed by BIOS.
  - `Max`: Full CoolBoost fan speed (100% RPM).
  - `Custom`: Interactive dual sliders to dial in custom target percentages (0–100%) for both CPU and GPU fans.
- **Battery Health Care & USB Power:**
  - **80% Battery Limit:** Preserves long-term battery lifespan by capping maximum charge.
  - **Battery Calibration:** Triggers the factory battery calibration discharge/charge cycle.
  - **USB Power-off Charging:** Set battery cutoff thresholds (`Off`, `10%`, `20%`, `30%`) to charge external devices when the laptop is shut down.
- **Hardware Tweaks:**
  - **LCD Overdrive:** Toggles 3ms panel response time acceleration.
  - **Keyboard Backlight Timeout:** Toggles the 30-second idle backlight sleep timer.
  - **BIOS Boot Sound:** Enables or disables the startup chime and animation.
- **Hybrid Graphics (Optimus):** Quick switching between `Hybrid`, `Integrated`, and `Nvidia` graphics modes via `envycontrol`.
- **Minimalist Bar Widget:** Clean laptop icon (`󰌢`) on the taskbar with urgent-color alerting during Max fan speed, and a rich telemetry tooltip on hover.

---

## 📋 Prerequisites

1. **Linux Kernel Module (`linuwu_sense`):**
   The [`linuwu_sense`](https://github.com/0x1e-lab/linuwu-sense) kernel driver must be compiled and loaded to expose the Acer WMI gaming attributes in sysfs.
   ```bash
   lsmod | grep linuwu_sense
   ```
2. **Polkit & `pkexec`:**
   Required for non-root execution of sysfs write commands and GPU switching.
3. **`jq`:**
   Required by the helper backend to output structured JSON telemetry.
4. **`envycontrol` (Optional):**
   Required only for hybrid GPU switching on Optimus laptops (`yay -S envycontrol`).

---

## 📦 Installation

### Method A: Manual Git Clone (Recommended)

1. Clone the repository into your Omarchy shell plugins directory:
   ```bash
   mkdir -p ~/.config/omarchy/plugins
   git clone https://github.com/felipeasp/omanitro.git ~/.config/omarchy/plugins/io.github.felipeasp.omanitro
   ```

2. Make backend scripts executable:
   ```bash
   chmod +x ~/.config/omarchy/plugins/io.github.felipeasp.omanitro/scripts/nitro-helper.sh
   chmod +x ~/.config/omarchy/plugins/io.github.felipeasp.omanitro/bin/omarchy-omanitro
   ```

3. Enable the plugin in your Omarchy bar (e.g. right section):
   ```bash
   omarchy plugin enable io.github.felipeasp.omanitro --section right
   ```

4. Refresh the Omarchy desktop shell:
   ```bash
   omarchy-shell io.github.felipeasp.omanitro refresh
   # Or restart the shell session:
   omarchy restart shell
   ```

### Method B: System-Wide Helper & Passwordless Polkit Setup

To enable passwordless operation for users in the `wheel` group and enable boot state restoration:
```bash
cd ~/.config/omarchy/plugins/io.github.felipeasp.omanitro
sudo ./install.sh
```

---

## 🖥️ CLI Usage

The plugin includes a command-line interface integrated with Omarchy:

```bash
# View complete hardware status and telemetry
omarchy omanitro status

# Output telemetry in compact JSON
omarchy omanitro status --json

# Fan controls
omarchy omanitro fan auto
omarchy omanitro fan max
omarchy omanitro fan set 60 70

# ACPI thermal profiles
omarchy omanitro profile set quiet
omarchy omanitro profile set balanced
omarchy omanitro profile set balanced-performance
omarchy omanitro profile set performance

# Battery care
omarchy omanitro battery limit on
omarchy omanitro battery limit off
omarchy omanitro battery calibrate start

# USB power-off charging threshold
omarchy omanitro usb set 30

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

## 🔍 Troubleshooting

### 1. Verify Kernel Module Loading
Ensure the kernel driver is active:
```bash
lsmod | grep linuwu_sense
```
If it is not loaded, load it manually or ensure your DKMS package is built:
```bash
sudo modprobe linuwu_sense
```

### 2. Verify Sysfs Nodes
OmaNitro dynamically detects either `nitro_sense` or `predator_sense` under Acer WMI platform drivers:
```bash
# Check if nitro_sense exists:
ls -la /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense/

# Fallback path for Predator models:
ls -la /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/

# Check hardware monitor sensors (fan RPM & temperatures):
ls -la /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/hwmon/hwmon*/
```

If the paths above do not exist, verify that your laptop model is supported by `linuwu_sense` and check `dmesg | grep -i acer`.

### 3. Test Backend Telemetry Directly
Run the helper script directly to inspect raw JSON output:
```bash
~/.config/omarchy/plugins/io.github.felipeasp.omanitro/scripts/nitro-helper.sh status
```

### 4. Inspect Shell Logs
To verify Omarchy shell plugin events and QML lifecycle:
```bash
journalctl --user -u omarchy-shell -f
# Or monitor general shell logs:
journalctl --since "5 minutes ago" | grep -i "omanitro"
```

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for details.
