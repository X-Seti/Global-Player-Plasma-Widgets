#!/usr/bin/env bash
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
if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  systemctl --user restart plasma-plasmashell.service
elif command -v kquitapp6 >/dev/null 2>&1; then
  kquitapp6 plasmashell || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
else
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[✓] Global Player v3.2 fully removed."
