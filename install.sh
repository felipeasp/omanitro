#!/usr/bin/env bash
# ==============================================================================
# install.sh - User Installer for OmaNitro Hardware Plugin
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PLUGIN_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------------------
# Security Check: Refuse execution as root from user-writable directories
# ------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  SRC_OWNER="$(stat -c '%u' "$PLUGIN_SRC_DIR" 2>/dev/null || echo "1000")"
  SRC_PERMS="$(stat -c '%a' "$PLUGIN_SRC_DIR" 2>/dev/null || echo "777")"

  if [[ "$SRC_OWNER" -ne 0 ]] || (( (SRC_PERMS & 0022) != 0 )); then
    echo -e "${RED}Security Error: install.sh must refuse to run as root directly from a user-writable directory.${NC}" >&2
    echo -e "${RED}The source directory '${PLUGIN_SRC_DIR}' is owned by UID ${SRC_OWNER} or writable by non-root users.${NC}" >&2
    echo -e "${YELLOW}To install user plugin files, run without sudo:${NC}" >&2
    echo -e "  ${BOLD}./install.sh${NC}" >&2
    echo -e "${YELLOW}To install privileged system components (Polkit rules, systemd service, /usr/bin/omarchy-omanitro), run:${NC}" >&2
    echo -e "  ${BOLD}sudo ./install-privileged.sh${NC}\n" >&2
    exit 1
  fi
  # If executed as root in a restricted root-owned environment, delegate to privileged installer
  exec "${PLUGIN_SRC_DIR}/install-privileged.sh" "$@"
fi

# ------------------------------------------------------------------------------
# Validation Helpers
# ------------------------------------------------------------------------------
check_not_symlink() {
  local target="$1"
  if [[ -L "$target" ]]; then
    echo -e "${RED}Security Error: '${target}' is a symbolic link. Symbolic links are strictly prohibited.${NC}" >&2
    exit 1
  fi
}

check_regular_file() {
  local target="$1"
  if [[ ! -f "$target" ]]; then
    echo -e "${RED}Security Error: '${target}' is not a regular file.${NC}" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# User Plugin Installation
# ------------------------------------------------------------------------------
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}${BOLD}=== Installing OmaNitro Hardware Plugin ===${NC}\n"

if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
  TARGET_PLUGIN_DIR="${USER_HOME}/.config/omarchy/plugins/io.github.felipeasp.omanitro"
  echo -e "${BLUE}==>${NC} Installing shell plugin to ${TARGET_PLUGIN_DIR}..."
  rm -rf "$TARGET_PLUGIN_DIR"
  mkdir -p "${TARGET_PLUGIN_DIR}/scripts"

  for asset in "manifest.json" "BarWidget.qml" "Panel.qml"; do
    src="${PLUGIN_SRC_DIR}/${asset}"
    check_not_symlink "$src"
    check_regular_file "$src"
    cp -f "$src" "$TARGET_PLUGIN_DIR/"
  done

  if [[ -f "${PLUGIN_SRC_DIR}/preview.png" ]]; then
    src="${PLUGIN_SRC_DIR}/preview.png"
    check_not_symlink "$src"
    check_regular_file "$src"
    cp -f "$src" "$TARGET_PLUGIN_DIR/"
  fi

  src_helper="${PLUGIN_SRC_DIR}/scripts/nitro-helper.sh"
  check_not_symlink "$src_helper"
  check_regular_file "$src_helper"
  cp -f "$src_helper" "${TARGET_PLUGIN_DIR}/scripts/"
  chmod +x "${TARGET_PLUGIN_DIR}/scripts/nitro-helper.sh"

  echo -e "${GREEN}✓ Shell plugin files installed.${NC}"
fi

# ------------------------------------------------------------------------------
# User CLI Installation
# ------------------------------------------------------------------------------
USER_BIN_INSTALLED="false"
if [[ -d "${USER_HOME}/Work/bin" ]]; then
  src_cli="${PLUGIN_SRC_DIR}/bin/omarchy-omanitro"
  check_not_symlink "$src_cli"
  check_regular_file "$src_cli"
  install -m 755 "$src_cli" "${USER_HOME}/Work/bin/omarchy-omanitro"
  USER_BIN_INSTALLED="true"
fi

if [[ -d "${USER_HOME}/.local/bin" && "$USER_BIN_INSTALLED" == "false" ]]; then
  src_cli="${PLUGIN_SRC_DIR}/bin/omarchy-omanitro"
  check_not_symlink "$src_cli"
  check_regular_file "$src_cli"
  install -m 755 "$src_cli" "${USER_HOME}/.local/bin/omarchy-omanitro"
  USER_BIN_INSTALLED="true"
fi

echo -e "\n${GREEN}${BOLD}✓ OmaNitro user plugin setup complete!${NC}\n"
echo -e "${YELLOW}Note: To install system-wide Polkit rules and privileged helpers (/usr/bin/omarchy-omanitro, /usr/lib/omanitro/nitro-helper.sh, systemd service), run:${NC}"
echo -e "  ${BOLD}sudo ./install-privileged.sh${NC}\n"
