#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Uninstaller for OmaNitro Shell Plugin
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}=== Removing OmaNitro Shell Plugin ===${NC}\n"

if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
  rm -f "${USER_HOME}/Work/bin/omarchy-omanitro" 2>/dev/null || true
  rm -f "${USER_HOME}/.local/bin/omarchy-omanitro" 2>/dev/null || true
  rm -rf "${USER_HOME}/.config/omarchy/plugins/io.github.felipeasp.omanitro"
  rm -rf "${USER_HOME}/.config/omarchy/plugins/omanitro"
  echo -e "${GREEN}✓ User plugin files removed.${NC}"
fi

echo -e "\n${YELLOW}Note: If you installed the system-wide package, remove it using your package manager:${NC}"
echo -e "  sudo pacman -R omanitro\n"
