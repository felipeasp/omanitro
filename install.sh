#!/usr/bin/env bash
# ==============================================================================
# install.sh - User-Space Installer for OmaNitro Shell Plugin
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
# Security Boundary Enforcement:
# Refuse root execution. The shell plugin installer operates strictly in user space.
# ------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}Security Error: install.sh is an unprivileged user-space installer and must NOT be run as root.${NC}" >&2
  echo -e "${YELLOW}Privileged system components (Polkit rules, systemd service, CLI) are decoupled from the user checkout.${NC}" >&2
  echo -e "${YELLOW}To install system components, use your system package manager:${NC}" >&2
  echo -e "  ${BOLD}yay -S omanitro${NC}\n" >&2
  echo -e "Or execute the independent root bootstrap installer:${NC}" >&2
  echo -e "  ${BOLD}curl -fsSL https://raw.githubusercontent.com/felipeasp/omanitro/v1.0.0/bootstrap/install-system.sh | sudo bash${NC}\n" >&2
  exit 1
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
REAL_USER="$(whoami)"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}${BOLD}=== Installing OmaNitro Shell Plugin ===${NC}\n"

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

  echo -e "${GREEN}✓ Shell plugin files installed successfully.${NC}"
fi

# ------------------------------------------------------------------------------
# User CLI Installation (Optional fallback for unprivileged environments)
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
echo -e "${YELLOW}Note: For passwordless hardware control, systemd state restoration, and /usr/bin/omarchy-omanitro,${NC}"
echo -e "${YELLOW}install the system package via your package manager:${NC}"
echo -e "  ${BOLD}yay -S omanitro${NC}"
echo -e "${YELLOW}Or execute the standalone root bootstrap:${NC}"
echo -e "  ${BOLD}curl -fsSL https://raw.githubusercontent.com/felipeasp/omanitro/v1.0.0/bootstrap/install-system.sh | sudo bash${NC}\n"
