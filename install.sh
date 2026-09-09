#!/usr/bin/env bash
# ==============================================================================
# install.sh - Installer for OmaNitro Hardware Plugin for Acer Nitro 5
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PLUGIN_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If run without sudo, install the user-level plugin files
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}${BOLD}=== Installing OmaNitro Hardware Plugin ===${NC}\n"

# 1. User Plugin Installation (~/.config/omarchy/plugins/io.github.felipeasp.omanitro/)
if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
  TARGET_PLUGIN_DIR="${USER_HOME}/.config/omarchy/plugins/io.github.felipeasp.omanitro"
  echo -e "${BLUE}==>${NC} Installing shell plugin to ${TARGET_PLUGIN_DIR}..."
  rm -rf "$TARGET_PLUGIN_DIR"
  mkdir -p "${TARGET_PLUGIN_DIR}/scripts"

  cp -f "${PLUGIN_SRC_DIR}/manifest.json" "$TARGET_PLUGIN_DIR/"
  cp -f "${PLUGIN_SRC_DIR}/BarWidget.qml" "$TARGET_PLUGIN_DIR/"
  cp -f "${PLUGIN_SRC_DIR}/Panel.qml" "$TARGET_PLUGIN_DIR/"
  if [[ -f "${PLUGIN_SRC_DIR}/preview.png" ]]; then
    cp -f "${PLUGIN_SRC_DIR}/preview.png" "$TARGET_PLUGIN_DIR/"
  fi
  cp -f "${PLUGIN_SRC_DIR}/scripts/nitro-helper.sh" "${TARGET_PLUGIN_DIR}/scripts/"
  chmod +x "${TARGET_PLUGIN_DIR}/scripts/nitro-helper.sh"

  if [[ $EUID -eq 0 ]]; then
    chown -R "$REAL_USER:$REAL_USER" "$TARGET_PLUGIN_DIR"
  fi
  echo -e "${GREEN}✓ Shell plugin files installed.${NC}"
fi

# 2. Privileged System Files (Only if run as root)
if [[ $EUID -eq 0 ]]; then
  echo -e "${BLUE}==>${NC} Installing privileged helper in /usr/lib/omanitro/..."
  mkdir -p /usr/lib/omanitro
  install -m 755 "${PLUGIN_SRC_DIR}/scripts/nitro-helper.sh" /usr/lib/omanitro/nitro-helper.sh

  echo -e "${BLUE}==>${NC} Installing Polkit policy and rules..."
  mkdir -p /usr/share/polkit-1/actions /etc/polkit-1/rules.d
  install -m 644 "${PLUGIN_SRC_DIR}/polkit/io.github.felipeasp.omanitro.policy" /usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy
  install -m 644 "${PLUGIN_SRC_DIR}/polkit/50-io.github.felipeasp.omanitro.rules" /etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules

  echo -e "${BLUE}==>${NC} Installing CLI command in /usr/bin/..."
  install -m 755 "${PLUGIN_SRC_DIR}/bin/omarchy-omanitro" /usr/bin/omarchy-omanitro

  if [[ -f "${PLUGIN_SRC_DIR}/systemd/omanitro.service" ]]; then
    echo -e "${BLUE}==>${NC} Installing systemd state-restoration service..."
    install -m 644 "${PLUGIN_SRC_DIR}/systemd/omanitro.service" /etc/systemd/system/omanitro.service
    systemctl daemon-reload
    systemctl enable --now omanitro.service 2>/dev/null || true
  fi
  echo -e "${GREEN}✓ Privileged system files installed.${NC}"
else
  echo -e "${YELLOW}Note: To install system-wide Polkit rules and /usr/lib/omanitro/nitro-helper.sh, run:${NC}"
  echo -e "  ${BOLD}sudo ./install.sh${NC}"
fi

# 3. CLI in user bin
if [[ -d "${USER_HOME}/Work/bin" ]]; then
  install -m 755 "${PLUGIN_SRC_DIR}/bin/omarchy-omanitro" "${USER_HOME}/Work/bin/omarchy-omanitro"
fi

echo -e "\n${GREEN}${BOLD}✓ OmaNitro setup complete!${NC}"
