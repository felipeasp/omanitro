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

# ==============================================================================
# Trusted SHA256 Checksum Manifest for Privileged Installation Files
# Every privileged file installed into root targets (/usr/bin, /usr/lib,
# /etc/polkit-1/rules.d, /usr/share/polkit-1/actions, /etc/systemd/system) must
# strictly match its immutable digest.
# ==============================================================================
declare -A PRIVILEGED_CHECKSUMS=(
  ["bin/omarchy-omanitro"]="a573feb9b73c67eb4b8c048b6382c0b0a5c1759c4fae0c32435b36fdaff1527b"
  ["scripts/nitro-helper.sh"]="35c102aab410b830787fd4fbb5651dd1c7b97707e6089820c71d0bde4d6eff3d"
  ["polkit/io.github.felipeasp.omanitro.policy"]="ddf1d22b09076bb28853bf67b9caab945409fb9c3e28f616dde5e10448704ca3"
  ["polkit/50-io.github.felipeasp.omanitro.rules"]="4ff1582ea72e10c654954ad60d035393dbbda505031a872a73161ff8469ce713"
  ["systemd/omanitro.service"]="69b4c8a9dfc5cd6a0b2af3b7463fe1a8e59f5c09114dfebc1cc032750830d09e"
)

PRIVILEGED_ORDER=(
  "bin/omarchy-omanitro"
  "scripts/nitro-helper.sh"
  "polkit/io.github.felipeasp.omanitro.policy"
  "polkit/50-io.github.felipeasp.omanitro.rules"
  "systemd/omanitro.service"
)

USER_PLUGIN_ASSETS=(
  "manifest.json"
  "BarWidget.qml"
  "Panel.qml"
  "preview.png"
)

# ------------------------------------------------------------------------------
# Security Verification Functions
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

verify_file_digest() {
  local target="$1"
  local expected_hash="$2"

  check_not_symlink "$target"
  check_regular_file "$target"

  local actual_hash
  actual_hash="$(sha256sum "$target" | awk '{print $1}')"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo -e "${RED}Security Error: SHA256 integrity verification failed for '${target}'.${NC}" >&2
    echo -e "${RED}  Expected: ${expected_hash}${NC}" >&2
    echo -e "${RED}  Actual:   ${actual_hash}${NC}" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Secure Root Staging
# ------------------------------------------------------------------------------
INSTALL_SRC_DIR="$PLUGIN_SRC_DIR"
SECURE_TMP_DIR=""

cleanup() {
  if [[ -n "${SECURE_TMP_DIR:-}" && -d "${SECURE_TMP_DIR:-}" ]]; then
    rm -rf "$SECURE_TMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

if [[ $EUID -eq 0 ]]; then
  echo -e "${BLUE}==>${NC} Initializing secure root staging area (0700 root:root)..."
  SECURE_TMP_DIR="$(mktemp -d)"
  chown root:root "$SECURE_TMP_DIR"
  chmod 0700 "$SECURE_TMP_DIR"

  # Stage only verified regular files into isolated root temporary staging area.
  # Symlinks are strictly rejected; recursive copying (cp -a) is eliminated.
  for rel_path in "${PRIVILEGED_ORDER[@]}"; do
    src_file="${PLUGIN_SRC_DIR}/${rel_path}"
    expected_hash="${PRIVILEGED_CHECKSUMS[$rel_path]}"

    verify_file_digest "$src_file" "$expected_hash"

    staged_dest="${SECURE_TMP_DIR}/${rel_path}"
    mkdir -p "$(dirname "$staged_dest")"
    cp -f "$src_file" "$staged_dest"
    chown root:root "$staged_dest"
    chmod 0600 "$staged_dest"
  done

  for rel_path in "${USER_PLUGIN_ASSETS[@]}"; do
    src_file="${PLUGIN_SRC_DIR}/${rel_path}"
    if [[ ! -e "$src_file" ]]; then
      continue
    fi
    check_not_symlink "$src_file"
    check_regular_file "$src_file"

    staged_dest="${SECURE_TMP_DIR}/${rel_path}"
    mkdir -p "$(dirname "$staged_dest")"
    cp -f "$src_file" "$staged_dest"
    chown root:root "$staged_dest"
    chmod 0644 "$staged_dest"
  done

  INSTALL_SRC_DIR="$SECURE_TMP_DIR"
  echo -e "${GREEN}✓ Verified regular assets staged securely in root storage.${NC}\n"
fi

# Detect target user for desktop plugin installation
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}${BOLD}=== Installing OmaNitro Hardware Plugin ===${NC}\n"

# ------------------------------------------------------------------------------
# 1. User Plugin Installation (~/.config/omarchy/plugins/io.github.felipeasp.omanitro/)
# ------------------------------------------------------------------------------
if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
  TARGET_PLUGIN_DIR="${USER_HOME}/.config/omarchy/plugins/io.github.felipeasp.omanitro"
  echo -e "${BLUE}==>${NC} Installing shell plugin to ${TARGET_PLUGIN_DIR}..."
  rm -rf "$TARGET_PLUGIN_DIR"
  mkdir -p "${TARGET_PLUGIN_DIR}/scripts"

  for asset in "manifest.json" "BarWidget.qml" "Panel.qml"; do
    src="${INSTALL_SRC_DIR}/${asset}"
    check_not_symlink "$src"
    check_regular_file "$src"
    cp -f "$src" "$TARGET_PLUGIN_DIR/"
  done

  if [[ -f "${INSTALL_SRC_DIR}/preview.png" ]]; then
    src="${INSTALL_SRC_DIR}/preview.png"
    check_not_symlink "$src"
    check_regular_file "$src"
    cp -f "$src" "$TARGET_PLUGIN_DIR/"
  fi

  src_helper="${INSTALL_SRC_DIR}/scripts/nitro-helper.sh"
  verify_file_digest "$src_helper" "${PRIVILEGED_CHECKSUMS[scripts/nitro-helper.sh]}"
  cp -f "$src_helper" "${TARGET_PLUGIN_DIR}/scripts/"
  chmod +x "${TARGET_PLUGIN_DIR}/scripts/nitro-helper.sh"

  if [[ $EUID -eq 0 ]]; then
    chown -R "$REAL_USER:$REAL_USER" "$TARGET_PLUGIN_DIR"
  fi
  echo -e "${GREEN}✓ Shell plugin files installed.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Privileged System Files (Only if run as root)
# ------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo -e "${BLUE}==>${NC} Installing privileged helper in /usr/lib/omanitro/..."
  verify_file_digest "${INSTALL_SRC_DIR}/scripts/nitro-helper.sh" "${PRIVILEGED_CHECKSUMS[scripts/nitro-helper.sh]}"
  mkdir -p /usr/lib/omanitro
  install -m 755 "${INSTALL_SRC_DIR}/scripts/nitro-helper.sh" /usr/lib/omanitro/nitro-helper.sh

  echo -e "${BLUE}==>${NC} Installing Polkit policy and rules..."
  verify_file_digest "${INSTALL_SRC_DIR}/polkit/io.github.felipeasp.omanitro.policy" "${PRIVILEGED_CHECKSUMS[polkit/io.github.felipeasp.omanitro.policy]}"
  mkdir -p /usr/share/polkit-1/actions
  install -m 644 "${INSTALL_SRC_DIR}/polkit/io.github.felipeasp.omanitro.policy" /usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy

  verify_file_digest "${INSTALL_SRC_DIR}/polkit/50-io.github.felipeasp.omanitro.rules" "${PRIVILEGED_CHECKSUMS[polkit/50-io.github.felipeasp.omanitro.rules]}"
  mkdir -p /etc/polkit-1/rules.d
  install -m 644 "${INSTALL_SRC_DIR}/polkit/50-io.github.felipeasp.omanitro.rules" /etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules

  # Optional udev rule support if present
  for udev_entry in "${!PRIVILEGED_CHECKSUMS[@]}"; do
    if [[ "$udev_entry" == udev/*.rules ]]; then
      rule_file="${INSTALL_SRC_DIR}/${udev_entry}"
      if [[ -f "$rule_file" ]]; then
        echo -e "${BLUE}==>${NC} Installing udev rule..."
        verify_file_digest "$rule_file" "${PRIVILEGED_CHECKSUMS[$udev_entry]}"
        mkdir -p /etc/udev/rules.d
        install -m 644 "$rule_file" "/etc/udev/rules.d/$(basename "$rule_file")"
        udevadm control --reload-rules 2>/dev/null || true
        udevadm trigger 2>/dev/null || true
      fi
    fi
  done

  echo -e "${BLUE}==>${NC} Installing CLI command in /usr/bin/..."
  verify_file_digest "${INSTALL_SRC_DIR}/bin/omarchy-omanitro" "${PRIVILEGED_CHECKSUMS[bin/omarchy-omanitro]}"
  install -m 755 "${INSTALL_SRC_DIR}/bin/omarchy-omanitro" /usr/bin/omarchy-omanitro

  if [[ -f "${INSTALL_SRC_DIR}/systemd/omanitro.service" ]]; then
    echo -e "${BLUE}==>${NC} Installing systemd state-restoration service..."
    verify_file_digest "${INSTALL_SRC_DIR}/systemd/omanitro.service" "${PRIVILEGED_CHECKSUMS[systemd/omanitro.service]}"
    install -m 644 "${INSTALL_SRC_DIR}/systemd/omanitro.service" /etc/systemd/system/omanitro.service
    systemctl daemon-reload
    systemctl enable --now omanitro.service 2>/dev/null || true
  fi
  echo -e "${GREEN}✓ Privileged system files verified and installed.${NC}"
else
  echo -e "${YELLOW}Note: To install system-wide Polkit rules and /usr/lib/omanitro/nitro-helper.sh, run:${NC}"
  echo -e "  ${BOLD}sudo ./install.sh${NC}"
fi

# ------------------------------------------------------------------------------
# 3. CLI in user bin
# ------------------------------------------------------------------------------
if [[ -d "${USER_HOME}/Work/bin" ]]; then
  src_cli="${INSTALL_SRC_DIR}/bin/omarchy-omanitro"
  verify_file_digest "$src_cli" "${PRIVILEGED_CHECKSUMS[bin/omarchy-omanitro]}"
  install -m 755 "$src_cli" "${USER_HOME}/Work/bin/omarchy-omanitro"
  if [[ $EUID -eq 0 ]]; then
    chown "$REAL_USER:$REAL_USER" "${USER_HOME}/Work/bin/omarchy-omanitro"
  fi
fi

echo -e "\n${GREEN}${BOLD}✓ OmaNitro setup complete!${NC}"
