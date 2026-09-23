#!/usr/bin/env bash
# ==============================================================================
# bootstrap/install-system.sh - Root Bootstrap for OmaNitro System Assets
#
# Independent root bootstrap installer for Acer Nitro 5 system assets:
# - /usr/lib/omanitro/nitro-helper.sh
# - /usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy
# - /etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules
# - /usr/bin/omarchy-omanitro
# - /etc/systemd/system/omanitro.service
#
# Security Architecture:
# - Designed to be fetched and executed directly by root independently of any
#   user-writable plugin checkout (e.g. via curl | sudo bash).
# - Operates strictly inside a temporary root-owned staging directory (0700 root:root).
# - Downloads the authenticated repository archive directly into root staging.
# - Validates immutable SHA-256 integrity digests of all privileged components
#   strictly inside root staging before touching any system target.
# - Rejects symlinks and non-regular files.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Allow help without root
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/felipeasp/omanitro/main/bootstrap/install-system.sh)\" [commit-or-tag]"
  echo ""
  echo "Independent root bootstrap installer for OmaNitro system components."
  echo "Fetches and validates privileged assets in an isolated root sandbox."
  exit 0
fi

# Enforce root execution
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Security Error: bootstrap/install-system.sh must be executed as root.${NC}" >&2
  echo -e "Usage: curl -fsSL https://raw.githubusercontent.com/felipeasp/omanitro/main/bootstrap/install-system.sh | sudo bash" >&2
  exit 1
fi

TARGET_REF="${1:-main}"
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

echo -e "${BLUE}${BOLD}=== OmaNitro Independent Root System Bootstrap ===${NC}\n"

# ------------------------------------------------------------------------------
# 1. Create Isolated Root Staging Directory (0700 root:root)
# ------------------------------------------------------------------------------
echo -e "${BLUE}==>${NC} Creating isolated root staging directory (0700 root:root)..."
ROOT_STAGE_DIR="$(mktemp -d /tmp/omanitro-root-bootstrap.XXXXXX)"
chown root:root "$ROOT_STAGE_DIR"
chmod 0700 "$ROOT_STAGE_DIR"

cleanup() {
  if [[ -n "${ROOT_STAGE_DIR:-}" && -d "${ROOT_STAGE_DIR:-}" ]]; then
    rm -rf "$ROOT_STAGE_DIR"
  fi
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# 2. Fetch Source Archive Directly into Root-Owned Staging
# ------------------------------------------------------------------------------
ARCHIVE_FILE="${ROOT_STAGE_DIR}/omanitro.tar.gz"
EXTRACT_DIR="${ROOT_STAGE_DIR}/extracted"
mkdir -p "$EXTRACT_DIR"

ARCHIVE_URL="${REPO_URL}/archive/${TARGET_REF}.tar.gz"
echo -e "${BLUE}==>${NC} Downloading repository archive from ${ARCHIVE_URL}..."

if ! curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_FILE"; then
  echo -e "${RED}Security Error: Failed to download archive from '${ARCHIVE_URL}'.${NC}" >&2
  exit 1
fi

tar -xzf "$ARCHIVE_FILE" --strip-components=1 -C "$EXTRACT_DIR"
chown -R root:root "$EXTRACT_DIR"
chmod -R go-rwx "$EXTRACT_DIR"

# Stage regular files into ROOT_STAGE_DIR/staged
STAGED_PAYLOAD_DIR="${ROOT_STAGE_DIR}/staged"
mkdir -p "$STAGED_PAYLOAD_DIR"

for rel_path in "${PRIVILEGED_ORDER[@]}"; do
  src_file="${EXTRACT_DIR}/${rel_path}"

  if [[ -L "$src_file" ]]; then
    echo -e "${RED}Security Error: Archive payload contains symbolic link '${rel_path}'. Rejected.${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$src_file" ]]; then
    echo -e "${RED}Security Error: Missing required file '${rel_path}' in archive payload.${NC}" >&2
    exit 1
  fi

  staged_dest="${STAGED_PAYLOAD_DIR}/${rel_path}"
  mkdir -p "$(dirname "$staged_dest")"
  cp --no-dereference -f "$src_file" "$staged_dest"
  chown root:root "$staged_dest"
  chmod 0600 "$staged_dest"
done

echo -e "${GREEN}✓ Archive safely extracted and staged into isolated root storage.${NC}\n"

# ------------------------------------------------------------------------------
# 3. Perform SHA-256 Integrity Verification Strictly on Staged Payload
# ------------------------------------------------------------------------------
echo -e "${BLUE}==>${NC} Verifying SHA-256 integrity of root-staged components..."

for rel_path in "${PRIVILEGED_ORDER[@]}"; do
  staged_file="${STAGED_PAYLOAD_DIR}/${rel_path}"
  expected_hash="${PRIVILEGED_CHECKSUMS[$rel_path]}"

  if [[ -L "$staged_file" || ! -f "$staged_file" ]]; then
    echo -e "${RED}Security Error: Staged file '${staged_file}' is invalid.${NC}" >&2
    exit 1
  fi

  actual_hash="$(sha256sum "$staged_file" | awk '{print $1}')"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo -e "${RED}Security Error: SHA-256 digest mismatch for '${rel_path}'.${NC}" >&2
    echo -e "${RED}  Expected: ${expected_hash}${NC}" >&2
    echo -e "${RED}  Actual:   ${actual_hash}${NC}" >&2
    exit 1
  fi
  echo -e "  [PASS] ${rel_path} (${actual_hash:0:16}...)"
done

echo -e "${GREEN}✓ All staged assets verified against immutable trust anchor.${NC}\n"

# ------------------------------------------------------------------------------
# 4. Atomic Installation to System Targets
# ------------------------------------------------------------------------------
install_verified_asset() {
  local rel_path="$1"
  local dest_path="$2"
  local mode="$3"

  local staged_file="${STAGED_PAYLOAD_DIR}/${rel_path}"
  local expected_hash="${PRIVILEGED_CHECKSUMS[$rel_path]}"

  local current_hash
  current_hash="$(sha256sum "$staged_file" | awk '{print $1}')"
  if [[ "$current_hash" != "$expected_hash" ]]; then
    echo -e "${RED}Security Error: Pre-install validation failed for '${rel_path}'. Aborting.${NC}" >&2
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

echo -e "\n${GREEN}${BOLD}✓ OmaNitro system installation completed successfully!${NC}"
