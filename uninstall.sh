#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh - Uninstaller for OmaNitro
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Execute como root: sudo $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "Desinstalando OmaNitro..."

systemctl stop omanitro.service 2>/dev/null || true
systemctl disable omanitro.service 2>/dev/null || true
rm -f /etc/systemd/system/omanitro.service
systemctl daemon-reload

rm -rf /usr/lib/omanitro
rm -f /usr/share/polkit-1/actions/io.github.felipeasp.omanitro.policy
rm -f /usr/share/polkit-1/actions/org.omarchy.omanitro.policy
rm -f /etc/polkit-1/rules.d/50-io.github.felipeasp.omanitro.rules
rm -f /etc/polkit-1/rules.d/50-org.omarchy.omanitro.rules
rm -f /usr/bin/omarchy-omanitro*
rm -f "${USER_HOME}/Work/bin"/omarchy-omanitro* 2>/dev/null || true

if [[ -n "$USER_HOME" ]]; then
  rm -rf "${USER_HOME}/.config/omarchy/plugins/io.github.felipeasp.omanitro"
  rm -rf "${USER_HOME}/.config/omarchy/plugins/omanitro"
fi

echo "Desinstalação do OmaNitro concluída com sucesso."
