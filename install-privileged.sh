#!/usr/bin/env bash
# ==============================================================================
# install-privileged.sh - Privileged Installer for OmaNitro System Components
#
# Installs root-owned system components:
# - /usr/lib/omanitro/nitro-helper.sh
# - /usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy
# - /etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules
# - /usr/bin/omarchy-omanitro
# - /etc/systemd/system/omanitro.service
#
# Security Architecture:
# - Must be executed directly by root (sudo ./install-privileged.sh).
# - Staging occurs strictly inside a temporary root-owned staging directory (0700 root:root).
# - Verifies SHA-256 integrity digests of all privileged components strictly inside
#   root staging before touching any system target.
# - Rejects symlinks and non-regular files.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow help without root
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: sudo ./install-privileged.sh [OPTIONS] [source-directory]"
  echo ""
  echo "Privileged installer for OmaNitro system components."
  echo ""
  echo "Options:"
  echo "  --local           Copy and verify assets from local repository (default)"
  echo "  --download        Download pinned commit archive directly into root staging"
  echo "  -h, --help        Show this help message"
  exit 0
fi

# Enforce root execution
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Security Error: install-privileged.sh must be executed as root.${NC}" >&2
  echo -e "Usage: sudo ./install-privileged.sh [OPTIONS] [source-directory]" >&2
  exit 1
fi

PINNED_COMMIT="3b8777ff145af0bc9094c2a417781fa4f4f4b8a8"
PINNED_ARCHIVE_SHA256="98aa232430dbd4b05cff634db63d791536ff2badfeeb1c0f490951e2e1d70430"
REPO_URL="https://github.com/felipeasp/omanitro"

# ==============================================================================
# Trusted SHA256 Checksum Manifest for Privileged Installation Files
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

DOWNLOAD_MODE="false"
SOURCE_DIR="$SCRIPT_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download|--remote)
      DOWNLOAD_MODE="true"
      shift
      ;;
    --local)
      DOWNLOAD_MODE="false"
      shift
      ;;
    *)
      if [[ -d "$1" ]]; then
        SOURCE_DIR="$(cd "$1" && pwd)"
      else
        echo -e "${RED}Unknown option or non-existent directory: $1${NC}" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# ------------------------------------------------------------------------------
# 1. Create Isolated Root Staging Directory (0700 root:root)
# ------------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}=== OmaNitro Privileged System Installation ===${NC}\n"
echo -e "${BLUE}==>${NC} Initializing secure root staging area (0700 root:root)..."

SECURE_STAGE_DIR="$(mktemp -d /tmp/omanitro-root-stage.XXXXXX)"
chown root:root "$SECURE_STAGE_DIR"
chmod 0700 "$SECURE_STAGE_DIR"

cleanup() {
  if [[ -n "${SECURE_STAGE_DIR:-}" && -d "${SECURE_STAGE_DIR:-}" ]]; then
    rm -rf "$SECURE_STAGE_DIR"
  fi
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# 2. Stage Assets into Root-Owned Storage FIRST
# ------------------------------------------------------------------------------
if [[ "$DOWNLOAD_MODE" == "true" ]]; then
  echo -e "${BLUE}==>${NC} Fetching immutable archive for commit ${PINNED_COMMIT} directly into root staging..."
  ARCHIVE_PATH="${SECURE_STAGE_DIR}/repo.tar.gz"
  EXTRACT_DIR="${SECURE_STAGE_DIR}/archive_extracted"
  mkdir -p "$EXTRACT_DIR"

  ARCHIVE_URL="${REPO_URL}/archive/${PINNED_COMMIT}.tar.gz"
  if ! curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"; then
    echo -e "${RED}Security Error: Failed to download repository archive from '${ARCHIVE_URL}'.${NC}" >&2
    exit 1
  fi

  ACTUAL_ARCHIVE_SHA256="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
  if [[ "$ACTUAL_ARCHIVE_SHA256" != "$PINNED_ARCHIVE_SHA256" ]]; then
    echo -e "${RED}Security Error: Archive SHA-256 digest mismatch.${NC}" >&2
    echo -e "${RED}  Expected: ${PINNED_ARCHIVE_SHA256}${NC}" >&2
    echo -e "${RED}  Actual:   ${ACTUAL_ARCHIVE_SHA256}${NC}" >&2
    exit 1
  fi

  tar -xzf "$ARCHIVE_PATH" --strip-components=1 -C "$EXTRACT_DIR"
  chown -R root:root "$EXTRACT_DIR"
  chmod -R go-rwx "$EXTRACT_DIR"

  for rel_path in "${PRIVILEGED_ORDER[@]}"; do
    src_file="${EXTRACT_DIR}/${rel_path}"
    if [[ -L "$src_file" ]]; then
      echo -e "${RED}Security Error: Downloaded archive contains symbolic link at '${rel_path}'. Rejected.${NC}" >&2
      exit 1
    fi
    if [[ ! -f "$src_file" ]]; then
      echo -e "${RED}Security Error: Missing required file '${rel_path}' in archive.${NC}" >&2
      exit 1
    fi
    staged_dest="${SECURE_STAGE_DIR}/${rel_path}"
    mkdir -p "$(dirname "$staged_dest")"
    cp --no-dereference -f "$src_file" "$staged_dest"
    chown root:root "$staged_dest"
    chmod 0600 "$staged_dest"
  done
else
  echo -e "${BLUE}==>${NC} Staging local assets into root storage without following symlinks..."
  for rel_path in "${PRIVILEGED_ORDER[@]}"; do
    src_file="${SOURCE_DIR}/${rel_path}"

    if [[ -L "$src_file" ]]; then
      echo -e "${RED}Security Error: Source path '${src_file}' is a symbolic link. Symlinks are strictly prohibited.${NC}" >&2
      exit 1
    fi

    if [[ ! -f "$src_file" ]]; then
      echo -e "${RED}Security Error: Source path '${src_file}' does not exist or is not a regular file.${NC}" >&2
      exit 1
    fi

    staged_dest="${SECURE_STAGE_DIR}/${rel_path}"
    mkdir -p "$(dirname "$staged_dest")"

    cp --no-dereference -f "$src_file" "$staged_dest"
    chown root:root "$staged_dest"
    chmod 0600 "$staged_dest"

    if [[ -L "$staged_dest" || ! -f "$staged_dest" ]]; then
      echo -e "${RED}Security Error: Staged destination '${staged_dest}' is invalid or not a regular file.${NC}" >&2
      exit 1
    fi
  done
fi

echo -e "${GREEN}✓ Source assets safely staged in isolated root directory.${NC}\n"

# ------------------------------------------------------------------------------
# 3. Perform SHA-256 Integrity Verification Strictly on Root-Staged Files
# ------------------------------------------------------------------------------
echo -e "${BLUE}==>${NC} Validating SHA-256 checksums strictly on root-staged files..."

for rel_path in "${PRIVILEGED_ORDER[@]}"; do
  staged_file="${SECURE_STAGE_DIR}/${rel_path}"
  expected_hash="${PRIVILEGED_CHECKSUMS[$rel_path]}"

  if [[ -L "$staged_file" || ! -f "$staged_file" ]]; then
    echo -e "${RED}Security Error: Staged file '${staged_file}' is not a regular file.${NC}" >&2
    exit 1
  fi

  actual_hash="$(sha256sum "$staged_file" | awk '{print $1}')"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo -e "${RED}Security Error: SHA256 integrity verification failed for staged file '${rel_path}'.${NC}" >&2
    echo -e "${RED}  Expected: ${expected_hash}${NC}" >&2
    echo -e "${RED}  Actual:   ${actual_hash}${NC}" >&2
    exit 1
  fi
  echo -e "  [PASS] ${rel_path} (${actual_hash:0:16}...)"
done

echo -e "${GREEN}✓ All staged privileged files verified successfully.${NC}\n"

# ------------------------------------------------------------------------------
# 4. Atomic Installation to System Targets from Root-Staged Files
# ------------------------------------------------------------------------------
install_verified_asset() {
  local rel_path="$1"
  local dest_path="$2"
  local mode="$3"

  local staged_file="${SECURE_STAGE_DIR}/${rel_path}"
  local expected_hash="${PRIVILEGED_CHECKSUMS[$rel_path]}"

  local current_hash
  current_hash="$(sha256sum "$staged_file" | awk '{print $1}')"
  if [[ "$current_hash" != "$expected_hash" ]]; then
    echo -e "${RED}Security Error: Atomic pre-install digest mismatch for '${rel_path}'. Aborting.${NC}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dest_path")"
  install -m "$mode" "$staged_file" "$dest_path"
}

echo -e "${BLUE}==>${NC} Installing privileged helper in /usr/lib/omanitro/..."
install_verified_asset "scripts/nitro-helper.sh" "/usr/lib/omanitro/nitro-helper.sh" 755

echo -e "${BLUE}==>${NC} Installing Polkit policy and rules..."
install_verified_asset "polkit/io.github.felipeasp.omanitro.policy" "/usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy" 644
install_verified_asset "polkit/50-io.github.felipeasp.omanitro.rules" "/etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules" 644

echo -e "${BLUE}==>${NC} Installing CLI command in /usr/bin/..."
install_verified_asset "bin/omarchy-omanitro" "/usr/bin/omarchy-omanitro" 755

echo -e "${BLUE}==>${NC} Installing systemd state-restoration service..."
install_verified_asset "systemd/omanitro.service" "/etc/systemd/system/omanitro.service" 644

echo -e "${BLUE}==>${NC} Reloading systemd manager configuration..."
systemctl daemon-reload
systemctl enable --now omanitro.service 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}✓ OmaNitro privileged system installation complete!${NC}"
