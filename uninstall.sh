#!/usr/bin/env bash
# X-Seti (Mooheda) Aug14 2025 - Global Player
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer"

echo "[+] Stopping user service (if running)"
systemctl --user disable --now gpd.service || true
rm -f "${HOME}/.config/systemd/user/gpd.service"
systemctl --user daemon-reload || true

echo "[+] Removing plasmoid"
rm -rf "${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

echo "[+] Removing daemon"
rm -rf "${HOME}/globalplayer-daemon"

echo "[+] Removing config, cache and logs"
rm -rf "${HOME}/.config/globalplayer"
rm -rf "${HOME}/.cache/globalplayer"
rm -rf "${HOME}/globalplayer"

echo "[+] Restarting Plasma"
if command -v kquitapp6 >/dev/null 2>&1; then
  kquitapp6 plasmashell || true
  (sleep 1; kstart6 plasmashell)&
elif command -v kquitapp5 >/dev/null 2>&1; then
  kquitapp5 plasmashell || true
  (sleep 1; kstart5 plasmashell)&
fi

echo "[✓] Global Player v1.0 fully removed."