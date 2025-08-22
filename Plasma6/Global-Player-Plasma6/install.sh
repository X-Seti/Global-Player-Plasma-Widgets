#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer"
PLASMOID_SRC="$(dirname "$0")/${PLASMOID_ID}"
PLASMOID_DST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

DAEMON_SRC="$(dirname "$0")/globalplayer-daemon"
DAEMON_DST="${HOME}/globalplayer-daemon"

echo "[+] Installing dependencies for Plasma 6 (you may need sudo):"
echo "    Arch:          sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests python-pyqt6-webengine"
echo "    Debian/Ubuntu: sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests python3-pyqt6.qtwebengine"
echo "    Fedora:        sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests python3-pyqt6-webengine"

echo "[+] Installing plasmoid to ${PLASMOID_DST}"
mkdir -p "${PLASMOID_DST}"
rsync -a --delete "${PLASMOID_SRC}/" "${PLASMOID_DST}/" || cp -rf "${PLASMOID_SRC}/." "${PLASMOID_DST}/"

echo "[+] Installing daemon to ${DAEMON_DST}"
mkdir -p "${DAEMON_DST}"
rsync -a --delete "${DAEMON_SRC}/" "${DAEMON_DST}/" || cp -rf "${DAEMON_SRC}/." "${DAEMON_DST}/"

echo "[+] Installing systemd --user service"
mkdir -p "${HOME}/.config/systemd/user"
cp "$(dirname "$0")/gpd.service" "${HOME}/.config/systemd/user/gpd.service"
systemctl --user daemon-reload || true
systemctl --user enable --now gpd.service || true

echo "[+] Restarting Plasma (Plasma 6 compatible)"
# Try different restart methods
if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  echo "    Restarting via systemctl..."
  systemctl --user restart plasma-plasmashell.service
elif command -v kquitapp6 >/dev/null 2>&1; then
  echo "    Using Plasma 6 commands..."
  kquitapp6 plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
else
  echo "    Direct plasmashell restart..."
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[+] Waiting for services to start..."
sleep 5

echo "[+] Checking service status..."
if systemctl --user is-active gpd.service >/dev/null 2>&1; then
  echo "    ✓ Daemon service is running"
else
  echo "    ⚠ Daemon service may not be running. Check: systemctl --user status gpd.service"
fi

echo "[+] Done! Add the widget: 'Global Player'"
echo "    Right-click on panel/desktop → Add Widgets → Search for 'Global Player'"
echo ""
echo "    If the widget doesn't appear:"
echo "    1. Restart Plasma completely: systemctl --user restart plasma-plasmashell.service"
echo "    2. Check daemon logs: journalctl --user -u gpd.service -f"
echo "    3. Verify all dependencies are installed"
