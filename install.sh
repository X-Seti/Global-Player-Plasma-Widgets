#!/usr/bin/env bash
# X-Seti (Mooheda) Aug14 2025 - Global Player
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer"
PLASMOID_SRC="$(dirname "$0")/${PLASMOID_ID}"
PLASMOID_DST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

DAEMON_SRC="$(dirname "$0")/globalplayer-daemon"
DAEMON_DST="${HOME}/globalplayer-daemon"

echo "[+] Installing dependencies (you may need sudo):"
echo "    Debian/Ubuntu: sudo apt install mpv qdbus python3-dbus python3-gi python3-requests python3-pyqt5.qtwebengine"
echo "    Arch:          sudo pacman -S mpv qt5-tools python-dbus python-gobject python-requests python-pyqt5-webengine"
echo "    Fedora:        sudo dnf install mpv qt5-qttools python3-dbus python3-gobject python3-requests python3-qt5-webengine"

echo "[+] Installing plasmoid to ${PLASMOID_DST}"
mkdir -p "${PLASMOID_DST}"
rsync -a --delete "${PLASMOID_SRC}/" "${PLASMOID_DST}/"

echo "[+] Installing daemon to ${DAEMON_DST}"
mkdir -p "${DAEMON_DST}"
rsync -a --delete "${DAEMON_SRC}/" "${DAEMON_DST}/"

echo "[+] Installing systemd --user service"
mkdir -p "${HOME}/.config/systemd/user"
cp "$(dirname "$0")/gpd.service" "${HOME}/.config/systemd/user/gpd.service"
systemctl --user daemon-reload || true
systemctl --user enable --now gpd.service || true

echo "[+] Restarting Plasma (optional, if the widget doesn't refresh)"
if command -v kquitapp6 >/dev/null 2>&1; then
  kquitapp6 plasmashell || true
  (sleep 1; kstart6 plasmashell)&
elif command -v kquitapp5 >/dev/null 2>&1; then
  kquitapp5 plasmashell || true
  (sleep 1; kstart5 plasmashell)&
fi

echo "[+] Done. Add/refresh the widget: 'Global Player v1.0'"