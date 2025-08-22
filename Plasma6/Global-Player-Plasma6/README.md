# Global Player Plasma 6 Widget - X-Seti

A KDE Plasma 6 widget for listening to Global Player radio stations.

## Features
- Listen to Global Player stations (Heart, Capital, Classic FM, etc.)
- Album artwork display
- Panel and desktop widget modes
- Sign-in support for premium features
- Logging support

## Installation

1. Install dependencies:
   ```bash
   # Arch Linux
   sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests python-pyqt6-webengine
   
   # Ubuntu/Debian
   sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests python3-pyqt6.qtwebengine
   
   # Fedora
   sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests python3-pyqt6-webengine
   ```

2. Run the install script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Add the widget:
   - Right-click on panel or desktop
   - Select "Add Widgets"
   - Search for "Global Player"
   - Add to panel or desktop

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Troubleshooting

- Check daemon status: `systemctl --user status gpd.service`
- View daemon logs: `journalctl --user -u gpd.service -f`
- Restart Plasma: `systemctl --user restart plasma-plasmashell.service`

## Version
v3.2 - Plasma 6 Compatible
