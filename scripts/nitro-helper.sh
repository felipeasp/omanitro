#!/usr/bin/env bash
# ==============================================================================
# nitro-helper.sh - Elevated hardware helper for OmaNitro (io.github.felipeasp.omanitro)
# Provides hardware telemetry, cooling controls, platform power profiles,
# battery care, USB charging, hardware tweaks, and GPU switching for Acer Nitro / Predator.
# ==============================================================================
set -euo pipefail

HELPER_INSTALL_PATH="/usr/lib/omanitro/nitro-helper.sh"
CONFIG_DIR="/etc/omarchy"
CONFIG_FILE="${CONFIG_DIR}/omanitro.conf"

# ------------------------------------------------------------------------------
# Kernel Module & Sysfs Path Detection
# ------------------------------------------------------------------------------
ensure_module_loaded() {
  if ! lsmod | grep -q "^linuwu_sense\b"; then
    modprobe linuwu_sense 2>/dev/null || true
    sleep 0.3
  fi
}

detect_base_path() {
  ensure_module_loaded
  local nitro_path="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense"
  local predator_path="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense"

  if [[ -d "$nitro_path" ]]; then
    echo "$nitro_path"
    return 0
  elif [[ -d "$predator_path" ]]; then
    echo "$predator_path"
    return 0
  fi

  local fallback
  fallback=$(ls -d /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/*_sense 2>/dev/null | head -n1 || true)
  if [[ -n "$fallback" && -d "$fallback" ]]; then
    echo "$fallback"
    return 0
  fi

  return 1
}

detect_hwmon_path() {
  local hwmon_dir
  hwmon_dir=$(ls -d /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/hwmon/hwmon* 2>/dev/null | head -n1 || true)
  if [[ -n "$hwmon_dir" && -d "$hwmon_dir" ]]; then
    echo "$hwmon_dir"
    return 0
  fi
  return 1
}

# ------------------------------------------------------------------------------
# Dynamic Hardware Info Detection
# ------------------------------------------------------------------------------
get_device_model() {
  local model=""
  if [[ -f "/sys/class/dmi/id/product_name" ]]; then
    model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  fi
  if [[ -z "$model" && -f "/sys/class/dmi/id/sys_vendor" ]]; then
    model=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  fi
  if [[ -z "$model" ]]; then
    model="Acer Nitro 5"
  fi
  echo "$model" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

get_cpu_model() {
  local cpu=""
  cpu=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed -e 's/^[[:space:]]*//' -e 's/(R)//g' -e 's/(TM)//g' -e 's/ @.*//' -e 's/  */ /g' | tr -d '\r\n' || true)
  if [[ -z "$cpu" ]]; then
    cpu="Intel Core i5"
  fi
  echo "$cpu" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

get_gpu_model() {
  local gpu=""
  if command -v nvidia-smi &>/dev/null; then
    gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)
  fi
  if [[ -z "$gpu" ]] && command -v lspci &>/dev/null; then
    gpu=$(lspci 2>/dev/null | grep -i '3d\|vga' | grep -i 'nvidia' | sed -E 's/.*controller: //; s/.*\[//; s/\].*//' | head -n1 || true)
  fi
  if [[ -z "$gpu" ]]; then
    gpu="Integrated Graphics"
  fi
  echo "$gpu" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# ------------------------------------------------------------------------------
# Privilege Elevation Handling
# ------------------------------------------------------------------------------
ensure_root() {
  if [[ $EUID -eq 0 ]]; then
    local base
    if base=$(detect_base_path); then
      chmod -R a+r "$base" 2>/dev/null || true
    fi
    return 0
  fi

  local target_bin="$0"
  if [[ -x "$HELPER_INSTALL_PATH" ]]; then
    target_bin="$HELPER_INSTALL_PATH"
  fi

  if command -v pkexec &>/dev/null; then
    exec pkexec "$target_bin" "$@"
  elif command -v sudo &>/dev/null; then
    exec sudo "$target_bin" "$@"
  else
    echo "ERROR: Root privileges required but neither pkexec nor sudo is available." >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Configuration Persistence
# ------------------------------------------------------------------------------
save_config_key() {
  local key="$1"
  local val="$2"
  [[ $EUID -ne 0 ]] && return 0

  mkdir -p "$CONFIG_DIR" 2>/dev/null || true
  touch "$CONFIG_FILE" 2>/dev/null || true
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$CONFIG_FILE" 2>/dev/null || true
  else
    echo "${key}=${val}" >> "$CONFIG_FILE" 2>/dev/null || true
  fi
}

get_config_key() {
  local key="$1"
  local fallback="$2"
  if [[ -f "$CONFIG_FILE" ]] && grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    grep "^${key}=" "$CONFIG_FILE" | head -n1 | cut -d'=' -f2
  else
    echo "$fallback"
  fi
}

# ------------------------------------------------------------------------------
# Command: Status (Unified JSON Output)
# ------------------------------------------------------------------------------
get_status_json() {
  local base hwmon
  base=$(detect_base_path || true)
  hwmon=$(detect_hwmon_path || true)

  local device_model cpu_model gpu_model
  device_model=$(get_device_model)
  cpu_model=$(get_cpu_model)
  gpu_model=$(get_gpu_model)

  # 1. Fans & Temperatures
  local target_cpu=0 target_gpu=0 fan_mode="auto"
  if [[ -n "$base" && -f "${base}/fan_speed" ]]; then
    local raw_speed
    raw_speed=$(cat "${base}/fan_speed" 2>/dev/null || get_config_key "fan_speed" "0,0")
    IFS=',' read -r target_cpu target_gpu <<< "$raw_speed"
    target_cpu="${target_cpu:-0}"
    target_gpu="${target_gpu:-0}"
  else
    target_cpu=$(get_config_key "target_cpu" "0")
    target_gpu=$(get_config_key "target_gpu" "0")
  fi

  if [[ "$target_cpu" == "0" && "$target_gpu" == "0" ]]; then
    fan_mode="auto"
  elif [[ "$target_cpu" == "100" && "$target_gpu" == "100" ]]; then
    fan_mode="max"
  else
    fan_mode="custom"
  fi

  local cpu_rpm=0 gpu_rpm=0 cpu_temp=0 gpu_temp=0 sys_temp=0
  if [[ -n "$hwmon" && -d "$hwmon" ]]; then
    cpu_rpm=$(cat "${hwmon}/fan1_input" 2>/dev/null || echo 0)
    gpu_rpm=$(cat "${hwmon}/fan2_input" 2>/dev/null || echo 0)
    cpu_temp=$(awk '{print int($1/1000)}' "${hwmon}/temp1_input" 2>/dev/null || echo 0)
    gpu_temp=$(awk '{print int($1/1000)}' "${hwmon}/temp2_input" 2>/dev/null || echo 0)
    sys_temp=$(awk '{print int($1/1000)}' "${hwmon}/temp3_input" 2>/dev/null || echo 0)
  fi

  # 2. ACPI Platform Profile
  local current_profile="balanced"
  local profile_choices_json='["quiet","balanced","balanced-performance","performance"]'
  if [[ -f "/sys/firmware/acpi/platform_profile" ]]; then
    current_profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "balanced")
    current_profile="${current_profile// /}"
  fi
  if [[ -f "/sys/firmware/acpi/platform_profile_choices" ]]; then
    local choices_raw
    choices_raw=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || echo "quiet balanced balanced-performance performance")
    local parsed_choices
    parsed_choices=$(echo "$choices_raw" | jq -c -R 'split(" ") | map(select(length > 0))' 2>/dev/null || true)
    if [[ -n "$parsed_choices" ]]; then
      profile_choices_json="$parsed_choices"
    fi
  fi

  # 3. Battery Care
  local battery_limiter_raw="0"
  if [[ -n "$base" && -f "${base}/battery_limiter" ]]; then
    battery_limiter_raw=$(cat "${base}/battery_limiter" 2>/dev/null || get_config_key "battery_limiter" "0")
  else
    battery_limiter_raw=$(get_config_key "battery_limiter" "0")
  fi

  local battery_limiter="false"
  local battery_threshold=100
  if [[ "$battery_limiter_raw" == "1" ]]; then
    battery_limiter="true"
    battery_threshold=80
  fi

  local battery_calibrating="false"
  if [[ -n "$base" && -f "${base}/battery_calibration" ]]; then
    local cal_val
    cal_val=$(cat "${base}/battery_calibration" 2>/dev/null || echo "0")
    [[ "$cal_val" == "1" ]] && battery_calibrating="true"
  fi

  # 4. USB Power-off Charging (0, 10, 20, 30)
  local usb_charging=0
  if [[ -n "$base" && -f "${base}/usb_charging" ]]; then
    local usb_raw
    usb_raw=$(cat "${base}/usb_charging" 2>/dev/null || echo "0")
    if [[ "$usb_raw" =~ ^(0|10|20|30)$ ]]; then
      usb_charging="$usb_raw"
    fi
  fi

  # 5. Hardware Tweaks (LCD Override, Backlight Timeout, Boot Sound)
  local lcd_override="false"
  if [[ -n "$base" && -f "${base}/lcd_override" ]]; then
    local lcd_raw
    lcd_raw=$(cat "${base}/lcd_override" 2>/dev/null || echo "0")
    [[ "$lcd_raw" == "1" ]] && lcd_override="true"
  fi

  local backlight_timeout="false"
  if [[ -n "$base" && -f "${base}/backlight_timeout" ]]; then
    local bl_raw
    bl_raw=$(cat "${base}/backlight_timeout" 2>/dev/null || echo "0")
    [[ "$bl_raw" == "1" ]] && backlight_timeout="true"
  fi

  local boot_sound="false"
  if [[ -n "$base" && -f "${base}/boot_animation_sound" ]]; then
    local boot_raw
    boot_raw=$(cat "${base}/boot_animation_sound" 2>/dev/null || echo "0")
    [[ "$boot_raw" == "1" ]] && boot_sound="true"
  fi

  # 6. Hybrid GPU (EnvyControl)
  local gpu_mode="hybrid"
  local gpu_available="false"
  if command -v envycontrol &>/dev/null; then
    gpu_available="true"
    local q_mode
    q_mode=$(envycontrol --query 2>/dev/null || true)
    if [[ -n "$q_mode" ]]; then
      gpu_mode=$(echo "$q_mode" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    fi
  else
    gpu_mode="unsupported"
    gpu_available="false"
  fi

  # Generate unified JSON with jq for rock-solid escaping
  jq -n -c \
    --arg dev "$device_model" \
    --arg cpu "$cpu_model" \
    --arg gpu "$gpu_model" \
    --argjson cpu_temp "$cpu_temp" \
    --argjson gpu_temp "$gpu_temp" \
    --argjson sys_temp "$sys_temp" \
    --argjson cpu_rpm "$cpu_rpm" \
    --argjson gpu_rpm "$gpu_rpm" \
    --arg fan_mode "$fan_mode" \
    --argjson target_cpu "$target_cpu" \
    --argjson target_gpu "$target_gpu" \
    --arg current_profile "$current_profile" \
    --argjson profile_choices "$profile_choices_json" \
    --argjson battery_limiter "$battery_limiter" \
    --argjson battery_threshold "$battery_threshold" \
    --argjson battery_calibrating "$battery_calibrating" \
    --argjson usb_charging "$usb_charging" \
    --argjson lcd_override "$lcd_override" \
    --argjson backlight_timeout "$backlight_timeout" \
    --argjson boot_animation_sound "$boot_sound" \
    --arg gpu_mode "$gpu_mode" \
    --argjson gpu_available "$gpu_available" \
    '{
      device_model: $dev,
      cpu_model: $cpu,
      gpu_model: $gpu,
      cpu_temp: $cpu_temp,
      gpu_temp: $gpu_temp,
      sys_temp: $sys_temp,
      profile: $current_profile,
      profile_choices: $profile_choices,
      fan_mode: $fan_mode,
      target_cpu: $target_cpu,
      target_gpu: $target_gpu,
      fan1_rpm: $cpu_rpm,
      fan2_rpm: $gpu_rpm,
      cpu_rpm: $cpu_rpm,
      gpu_rpm: $gpu_rpm,
      battery_limiter: $battery_limiter,
      battery_threshold: $battery_threshold,
      battery_calibration: $battery_calibrating,
      usb_charging: $usb_charging,
      lcd_override: $lcd_override,
      backlight_timeout: $backlight_timeout,
      boot_animation_sound: $boot_animation_sound,
      gpu_mode: $gpu_mode,
      gpu_available: $gpu_available,
      fan: {
        mode: $fan_mode,
        target_cpu: $target_cpu,
        target_gpu: $target_gpu,
        cpu_rpm: $cpu_rpm,
        gpu_rpm: $gpu_rpm,
        cpu_temp: $cpu_temp,
        gpu_temp: $gpu_temp,
        sys_temp: $sys_temp
      },
      profile: {
        current: $current_profile,
        choices: $profile_choices
      },
      battery: {
        limiter: $battery_limiter,
        threshold: $battery_threshold,
        calibrating: $battery_calibrating
      },
      gpu: {
        mode: $gpu_mode,
        available: $gpu_available
      }
    }'
}

# ------------------------------------------------------------------------------
# Command Handlers
# ------------------------------------------------------------------------------
set_fan() {
  local subcmd="${1:-auto}"
  shift || true

  ensure_root fan "$subcmd" "$@"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  case "$subcmd" in
    auto)
      echo "0,0" > "${base}/fan_speed"
      save_config_key "fan_mode" "auto"
      save_config_key "fan_speed" "0,0"
      save_config_key "target_cpu" "0"
      save_config_key "target_gpu" "0"
      echo "OK: Fan set to Auto"
      ;;
    max)
      echo "100,100" > "${base}/fan_speed"
      save_config_key "fan_mode" "max"
      save_config_key "fan_speed" "100,100"
      save_config_key "target_cpu" "100"
      save_config_key "target_gpu" "100"
      echo "OK: Fan set to Max (100%)"
      ;;
    set)
      local cpu="${1:-50}"
      local gpu="${2:-50}"
      cpu=$(( cpu < 0 ? 0 : (cpu > 100 ? 100 : cpu) ))
      gpu=$(( gpu < 0 ? 0 : (gpu > 100 ? 100 : gpu) ))
      echo "${cpu},${gpu}" > "${base}/fan_speed"
      save_config_key "fan_mode" "custom"
      save_config_key "fan_speed" "${cpu},${gpu}"
      save_config_key "target_cpu" "$cpu"
      save_config_key "target_gpu" "$gpu"
      echo "OK: Fan set to CPU: ${cpu}%, GPU: ${gpu}%"
      ;;
    status)
      get_status_json
      ;;
    *)
      echo "Usage: $0 fan [auto|max|set <cpu> <gpu>|status]" >&2
      exit 1
      ;;
  esac
}

set_profile() {
  local prof="${1:-}"
  if [[ "$prof" == "set" ]]; then
    prof="${2:-balanced}"
  fi
  if [[ -z "$prof" ]]; then
    echo "Usage: $0 profile <quiet|balanced|balanced-performance|performance>" >&2
    exit 1
  fi

  ensure_root profile "$prof"

  case "$prof" in
    quiet|silent|low) prof="quiet" ;;
    balanced|normal|default) prof="balanced" ;;
    balanced-perf|balanced-performance|bal-perf) prof="balanced-performance" ;;
    performance|turbo|high) prof="performance" ;;
  esac

  if [[ -w "/sys/firmware/acpi/platform_profile" ]]; then
    echo "$prof" > /sys/firmware/acpi/platform_profile
  fi

  if command -v powerprofilesctl &>/dev/null; then
    local pctl_prof="$prof"
    [[ "$pctl_prof" == "balanced-performance" ]] && pctl_prof="performance"
    powerprofilesctl set "$pctl_prof" 2>/dev/null || true
  fi

  save_config_key "acpi_profile" "$prof"
  echo "OK: Profile set to $prof"
}

set_battery_limit() {
  local val="${1:-}"
  if [[ "$val" == "limit" ]]; then
    val="${2:-}"
  fi

  case "$val" in
    1|on|true|80) val="1" ;;
    0|off|false|100) val="0" ;;
    status)
      get_status_json
      return 0
      ;;
    *)
      echo "Usage: $0 battery_limit <0|1|on|off>" >&2
      exit 1
      ;;
  esac

  ensure_root battery_limit "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/battery_limiter"
  save_config_key "battery_limiter" "$val"
  echo "OK: Battery limit set to $val"
}

set_battery_calibrate() {
  local val="${1:-}"
  if [[ "$val" == "calibrate" ]]; then
    val="${2:-}"
  fi

  case "$val" in
    1|start|on|true) val="1" ;;
    0|stop|off|false) val="0" ;;
    status)
      get_status_json
      return 0
      ;;
    *)
      echo "Usage: $0 battery_calibrate <0|1|start|stop>" >&2
      exit 1
      ;;
  esac

  ensure_root battery_calibrate "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/battery_calibration"
  echo "OK: Battery calibrate set to $val"
}

set_usb_charging() {
  local val="${1:-0}"
  case "$val" in
    0|off|false) val="0" ;;
    10) val="10" ;;
    20) val="20" ;;
    30) val="30" ;;
    *)
      echo "Usage: $0 usb_charging <0|10|20|30>" >&2
      exit 1
      ;;
  esac

  ensure_root usb_charging "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/usb_charging"
  save_config_key "usb_charging" "$val"
  echo "OK: USB charging set to $val"
}

set_lcd_override() {
  local val="${1:-0}"
  case "$val" in
    1|on|true) val="1" ;;
    0|off|false) val="0" ;;
    *)
      echo "Usage: $0 lcd_override <0|1|on|off>" >&2
      exit 1
      ;;
  esac

  ensure_root lcd_override "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/lcd_override"
  save_config_key "lcd_override" "$val"
  echo "OK: LCD override set to $val"
}

set_backlight_timeout() {
  local val="${1:-0}"
  case "$val" in
    1|on|true) val="1" ;;
    0|off|false) val="0" ;;
    *)
      echo "Usage: $0 backlight_timeout <0|1|on|off>" >&2
      exit 1
      ;;
  esac

  ensure_root backlight_timeout "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/backlight_timeout"
  save_config_key "backlight_timeout" "$val"
  echo "OK: Backlight timeout set to $val"
}

set_boot_sound() {
  local val="${1:-0}"
  case "$val" in
    1|on|true) val="1" ;;
    0|off|false) val="0" ;;
    *)
      echo "Usage: $0 boot_sound <0|1|on|off>" >&2
      exit 1
      ;;
  esac

  ensure_root boot_sound "$val"
  local base
  base=$(detect_base_path) || { echo "ERROR: Sysfs base not found" >&2; exit 1; }

  echo "$val" > "${base}/boot_animation_sound"
  save_config_key "boot_sound" "$val"
  echo "OK: Boot animation sound set to $val"
}

set_gpu() {
  local mode="${1:-}"
  if [[ -z "$mode" || "$mode" == "status" ]]; then
    get_status_json
    return 0
  fi

  if ! command -v envycontrol &>/dev/null; then
    echo "ERROR: envycontrol is not installed on this system." >&2
    exit 1
  fi

  ensure_root gpu "$mode"

  case "$mode" in
    hybrid)
      envycontrol -s hybrid --coolbits 28
      save_config_key "gpu_mode" "hybrid"
      echo "OK: GPU mode set to hybrid"
      ;;
    integrated)
      envycontrol -s integrated
      save_config_key "gpu_mode" "integrated"
      echo "OK: GPU mode set to integrated"
      ;;
    nvidia)
      envycontrol -s nvidia --coolbits 28
      save_config_key "gpu_mode" "nvidia"
      echo "OK: GPU mode set to nvidia"
      ;;
    *)
      echo "Usage: $0 gpu <hybrid|integrated|nvidia>" >&2
      exit 1
      ;;
  esac
}

restore_state() {
  ensure_root restore
  local base
  base=$(detect_base_path) || return 0

  # 1. Restore battery limiter
  local batt_lim
  batt_lim=$(get_config_key "battery_limiter" "0")
  echo "$batt_lim" > "${base}/battery_limiter" 2>/dev/null || true

  # 2. Restore ACPI profile
  local profile
  profile=$(get_config_key "acpi_profile" "")
  if [[ -n "$profile" && -w "/sys/firmware/acpi/platform_profile" ]]; then
    echo "$profile" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
  fi

  # 3. Restore fan mode
  local fan_mode
  fan_mode=$(get_config_key "fan_mode" "auto")
  case "$fan_mode" in
    auto) echo "0,0" > "${base}/fan_speed" 2>/dev/null || true ;;
    max) echo "100,100" > "${base}/fan_speed" 2>/dev/null || true ;;
    custom)
      local cpu gpu
      cpu=$(get_config_key "target_cpu" "50")
      gpu=$(get_config_key "target_gpu" "50")
      echo "${cpu},${gpu}" > "${base}/fan_speed" 2>/dev/null || true
      ;;
  esac

  # 4. Restore USB charging
  local usb_val
  usb_val=$(get_config_key "usb_charging" "")
  if [[ -n "$usb_val" && -f "${base}/usb_charging" ]]; then
    echo "$usb_val" > "${base}/usb_charging" 2>/dev/null || true
  fi

  # 5. Restore LCD override
  local lcd_val
  lcd_val=$(get_config_key "lcd_override" "")
  if [[ -n "$lcd_val" && -f "${base}/lcd_override" ]]; then
    echo "$lcd_val" > "${base}/lcd_override" 2>/dev/null || true
  fi

  # 6. Restore Backlight timeout
  local bl_val
  bl_val=$(get_config_key "backlight_timeout" "")
  if [[ -n "$bl_val" && -f "${base}/backlight_timeout" ]]; then
    echo "$bl_val" > "${base}/backlight_timeout" 2>/dev/null || true
  fi

  # 7. Restore Boot sound
  local boot_val
  boot_val=$(get_config_key "boot_sound" "")
  if [[ -n "$boot_val" && -f "${base}/boot_animation_sound" ]]; then
    echo "$boot_val" > "${base}/boot_animation_sound" 2>/dev/null || true
  fi

  echo "OK: Omanitro state restored."
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
main() {
  local cmd="${1:-status}"
  shift || true

  case "$cmd" in
    status)
      get_status_json
      ;;
    fan)
      set_fan "$@"
      ;;
    profile)
      set_profile "$@"
      ;;
    battery_limit|battery-limit)
      set_battery_limit "$@"
      ;;
    battery_calibrate|battery-calibrate)
      set_battery_calibrate "$@"
      ;;
    battery)
      local sub="${1:-status}"
      shift || true
      if [[ "$sub" =~ ^(limit|limiter)$ ]]; then
        set_battery_limit "$@"
      elif [[ "$sub" =~ ^(calibrate|calibration)$ ]]; then
        set_battery_calibrate "$@"
      else
        get_status_json
      fi
      ;;
    usb_charging|usb-charging|usb)
      set_usb_charging "$@"
      ;;
    lcd_override|lcd-override|lcd)
      set_lcd_override "$@"
      ;;
    backlight_timeout|backlight-timeout|backlight)
      set_backlight_timeout "$@"
      ;;
    boot_sound|boot-sound|bootsound)
      set_boot_sound "$@"
      ;;
    gpu)
      set_gpu "$@"
      ;;
    restore)
      restore_state
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Available commands: status, fan, profile, battery_limit, battery_calibrate, usb_charging, lcd_override, backlight_timeout, boot_sound, gpu, restore" >&2
      exit 1
      ;;
  esac
}

main "$@"
