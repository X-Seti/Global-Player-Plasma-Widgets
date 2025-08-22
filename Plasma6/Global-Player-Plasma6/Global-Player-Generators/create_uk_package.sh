        elif "icy-title" in md:
            parts = (md.get("icy-title") or "").split(" - ", 1)
            if len(parts) == 2:
                artist, title = parts
            else:
                title = md.get("icy-title") or ""
        elif "StreamTitle" in md:
            parts = (md.get("StreamTitle") or "").split(" - ", 1)
            if len(parts) == 2:
                artist, title = parts
            else:
                title = md.get("StreamTitle") or ""

        # Only log on change
        track_id = f"{artist} — {title}".strip()
        if self.logging and track_id and track_id != self._last_track_id:
            self._last_track_id = track_id
            self._log_event(f"NowPlaying station={self.station} artist={artist} title={title}")

        art_path = artwork_for(artist, title) if (artist or title) else ""

        payload = {
            "station": self.station,
            "artist": artist,
            "title": title,
            "show": show,
            "state": self.player.state,
            "artworkPath": art_path
        }
        return json.dumps(payload)

    @dbus.service.method("org.mooheda.gpd1", out_signature="s")
    def GetState(self):
        payload = {
            "state": self.player.state,
            "station": self.station,
            "logging": self.logging
        }
        return json.dumps(payload)

    @dbus.service.method("org.mooheda.gpd1", out_signature="s")
    def GetStations(self):
        names = list(self.stations.keys())
        names.sort(key=lambda s: s.lower())
        return json.dumps(names)

    @dbus.service.method("org.mooheda.gpd1")
    def SignIn(self):
        # Launch a Qt WebEngine view to login and capture cookies for *.globalplayer.com
        code = r'''import os, sys
try:
    from PyQt6 import QtWidgets, QtCore, QtWebEngineWidgets
    qt_version = 6
except ImportError:
    try:
        from PyQt5 import QtWidgets, QtCore, QtWebEngineWidgets
        qt_version = 5
    except ImportError:
        print("ERROR: Neither PyQt6 nor PyQt5 with WebEngine found", file=sys.stderr)
        sys.exit(1)

DOMAIN = ".globalplayer.com"

class LoginWindow(QtWebEngineWidgets.QWebEngineView):
    def __init__(self):
        super().__init__()
        if qt_version == 6:
            self.profile = QtWebEngineWidgets.QWebEngineProfile.defaultProfile()
            self.page().profile().cookieStore().cookieAdded.connect(self.onCookieAdded)
        else:
            self.profile = QtWebEngineWidgets.QWebEngineProfile.defaultProfile()
            self.page().profile().cookieStore().cookieAdded.connect(self.onCookieAdded)
        self.cookies = []
        self.setWindowTitle("Global Player — Sign In")
        self.resize(900, 740)
        self.load(QtCore.QUrl("https://www.globalplayer.com/login/"))

    def onCookieAdded(self, cookie):
        try:
            if qt_version == 6:
                name = cookie.name().data().decode()
                value = cookie.value().data().decode()
            else:
                name = bytes(cookie.name()).decode()
                value = bytes(cookie.value()).decode()
            domain = cookie.domain()
            if domain and (DOMAIN in domain):
                self.cookies.append(f"{name}={value}")
        except Exception:
            pass

    def closeEvent(self, ev):
        jar = "; ".join(sorted(set(self.cookies)))
        sys.stdout.write(jar)
        sys.stdout.flush()
        super().closeEvent(ev)

app = QtWidgets.QApplication(sys.argv)
w = LoginWindow()
w.show()
app.exec() if qt_version == 6 else app.exec_()
'''
        try:
            p = subprocess.run(["python3", "-c", code], capture_output=True, text=True)
            if p.returncode == 0 and p.stdout.strip():
                jar = p.stdout.strip()
                kwallet_store("cookies", jar)
                self._log_event("SignIn success (cookies stored)")
            else:
                self._log_event(f"SignIn failed: {p.stderr}")
        except Exception as e:
            self._log_event(f"SignIn failed or canceled: {e}")

    def _log_event(self, text):
        ensure_dirs()
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{timestamp} | {text}\n")

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.mooheda.gpd", bus)
    gpd = GlobalPlayerDaemon(bus)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
EOF

echo "[+] Creating MPV player (UK version)..."
cat > "globalplayer-daemon/playback_mpv.py" << 'EOF'
#X-Seti - Aug12 2025 - GlobalPlayer
import os, json, socket, subprocess, threading, time, tempfile

class MPVPlayer:
    def __init__(self, socket_path=None):
        self.proc = None
        self.sock_path = socket_path or os.path.join(tempfile.gettempdir(), "gpd-mpv.sock")
        self.state = "Stopped"

    def _cleanup_socket(self):
        try:
            if os.path.exists(self.sock_path):
                os.remove(self.sock_path)
        except Exception:
            pass

    def play(self, url):
        self.stop()
        self._cleanup_socket()
        cmd = ["mpv", "--no-video", "--idle=yes",
               f"--input-ipc-server={self.sock_path}",
               "--term-status-msg=",
               url]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.state = "Playing"
        time.sleep(0.3)

    def pause(self):
        if self.proc:
            self._send({"command": ["set_property", "pause", True]})
            self.state = "Paused"

    def resume(self):
        if self.proc:
            self._send({"command": ["set_property", "pause", False]})
            self.state = "Playing"

    def stop(self):
        if self.proc:
            try:
                self._send({"command": ["quit"]})
            except Exception:
                pass
            try:
                self.proc.terminate()
            except Exception:
                pass
            self.proc = None
        self.state = "Stopped"
        self._cleanup_socket()

    def _send(self, obj):
        for _ in range(3):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(self.sock_path)
                s.send((json.dumps(obj) + "\n").encode("utf-8"))
                s.close()
                return
            except Exception:
                time.sleep(0.1)

    def get_metadata(self):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.sock_path)
            s.send((json.dumps({"command":["get_property","metadata"]}) + "\n").encode("utf-8"))
            buf = s.recv(65536).decode("utf-8")
            s.close()
            for line in buf.splitlines():
                try:
                    obj = json.loads(line)
                    if "data" in obj:
                        return obj.get("data") or {}
                except Exception:
                    continue
        except Exception:
            pass
        return {}
EOF

echo "[+] Creating systemd service..."
cat > "gpd.service" << 'EOF'
[Unit]
Description=Global Player Daemon v3.2

[Service]
Type=simple
ExecStart=/usr/bin/env python3 %h/globalplayer-daemon/gpd.py
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "[+] Creating install script..."
cat > "install.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer"
PLASMOID_SRC="$(dirname "$0")/${PLASMOID_ID}"
PLASMOID_DST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

DAEMON_SRC="$(dirname "$0")/globalplayer-daemon"
DAEMON_DST="${HOME}/globalplayer-daemon"

echo "[+] Installing Global Player UK for Plasma 6..."
echo ""
echo "🇬🇧 Featured UK Stations:"
echo "   • Heart (UK, London, 60s, 70s, 80s, 90s, 00s, Dance, Xmas)"
echo "   • Capital (UK, London, Dance, XTRA, XTRA Reloaded)"
echo "   • Classic FM & Classic FM Relax"
echo "   • LBC & LBC News"
echo "   • Smooth (UK, London, Chill, Country)"
echo "   • Radio X & Radio X Classic Rock"
echo "   • Gold"
echo ""
echo "[+] Dependencies needed:"
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

echo "[+] Restarting Plasma..."
if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  systemctl --user restart plasma-plasmashell.service
elif command -v kquitapp6 >/dev/null 2>&1; then
  kquitapp6 plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
else
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[+] Waiting for services to start..."
sleep 5

if systemctl --user is-active gpd.service >/dev/null 2>&1; then
  echo "    ✓ UK Daemon service is running"
else
  echo "    ⚠ UK Daemon service may not be running. Check: systemctl --user status gpd.service"
fi

echo ""
echo "🇬🇧 Global Player UK installed successfully!"
echo ""
echo "📱 To add widget:"
echo "   Right-click panel → Add Widgets → Search 'Global Player'"
echo ""
echo "🔐 Premium Features:"
echo "   • Use 'Sign In' button for premium Global Player features"
echo "   • Cookies stored securely in KWallet"
echo "   • Web scraping discovers additional stations automatically"
EOF

echo "[+] Creating uninstall script..."
cat > "uninstall.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer"

echo "[+] Uninstalling Global Player UK..."

systemctl --user disable --now gpd.service || true
rm -f "${HOME}/.config/systemd/user/gpd.service"
systemctl --user daemon-reload || true

rm -rf "${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
rm -rf "${HOME}/globalplayer-daemon"
rm -rf "${HOME}/.config/globalplayer"
rm -rf "${HOME}/.cache/globalplayer"
rm -rf "${HOME}/globalplayer"

if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  systemctl --user restart plasma-plasmashell.service
else
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[✓] Global Player UK completely removed."
EOF

echo "[+] Creating README..."
cat > "README.md" << 'EOF'
# 🇬🇧 Global Player UK - Plasma 6 Widget

The original KDE Plasma 6 widget for UK's Global Player stations with full premium features.

## 📻 Featured Stations

### Heart Network
- **Heart UK** - National hits
- **Heart London** - London regional
- **Heart 60s, 70s, 80s, 90s, 00s** - Decade-specific music
- **Heart Dance** - Dance music
- **Heart Xmas** - Christmas music (seasonal)

### Capital Network  
- **Capital UK** - National chart hits
- **Capital London** - London regional
- **Capital Dance** - Dance and electronic
- **Capital XTRA** - Hip-hop and R&B
- **Capital XTRA Reloaded** - Classic hip-hop

### Classic & Talk
- **Classic FM** - Classical music
- **Classic FM Relax** - Relaxing classical
- **LBC** - Talk radio and news
- **LBC News** - 24/7 news

### Smooth & Alternative
- **Smooth UK** - Easy listening hits
- **Smooth London** - London regional
- **Smooth Chill** - Chillout music
- **Smooth Country** - Country music
- **Radio X** - Alternative rock
- **Radio X Classic Rock** - Classic rock
- **Gold** - Greatest hits

## ✨ Premium Features
- 🔐 **Sign-in support** for Global Player premium features
- 🕸️ **Web scraping** automatically discovers new stations
- 🔑 **KWallet integration** for secure cookie storage
- 🎨 **Album artwork** in panel icon and notifications
- 🔔 **Desktop notifications** when songs change
- 🇬🇧 **UK theming** with Union Jack and blue accents
- 🎛️ **Mouse wheel** station switching in panel
- 📝 **Enhanced logging** with premium metadata

## 🚀 Installation

1. **Install dependencies**:
   ```bash
   # Arch Linux
   sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests python-pyqt6-webengine
   
   # Ubuntu/Debian
   sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests python3-pyqt6.qtwebengine
   
   # Fedora
   sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests python3-pyqt6-webengine
   ```

2. **Install widget**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Add to panel**: Right-click panel → Add Widgets → "Global Player"

4. **Sign in** (optional): Click "Sign In" for premium features

## 🔧 Technical Details
- **Original D-Bus service**: `org.mooheda.gpd`
- **Config location**: `~/.config/globalplayer/`
- **Cache location**: `~/.cache/globalplayer/`
- **Logs location**: `~/globalplayer/gp.logs`
- **Cookie storage**: KWallet integration

## 🌍 Global Player Premium
- **Sign-in** unlocks premium features on supported stations
- **Enhanced metadata** for better track information
- **Additional content** access where available
- **Secure authentication** via KWallet cookie storage

## 🛠️ Troubleshooting
- **Service status**: `systemctl --user status gpd.service`
- **View logs**: `journalctl --user -u gpd.service -f`
- **Restart Plasma**: `systemctl --user restart plasma-plasmashell.service`
- **Clear cookies**: Remove from KWallet if sign-in issues occur

## 📜 Version
v3.2 UK (Original) - Plasma 6 Compatible
Created by X-Seti (Mooheda) - August 2025

## 🚨 Note
Some stations may be geo-restricted outside the UK. Sign-in may provide access to additional content for UK users.
EOF

chmod +x install.sh uninstall.sh

cd ..

echo ""
echo "🇬🇧 Global Player UK (Original) package created successfully!"
echo ""
echo "📁 Package: ${PACKAGE_NAME}/"
echo ""
echo "📻 Complete Station Lineup:"
echo "   • Heart Network (UK, London, 60s-00s, Dance, Xmas)"
echo "   • Capital Network (UK, London, Dance, XTRA)"
echo "   • Classic FM & Classic FM Relax"
echo "   • LBC & LBC News"
echo "   • Smooth (UK, London, Chill, Country)"
echo "   • Radio X & Radio X Classic Rock"
echo "   • Gold"
echo ""
echo "✨ Premium Features:"
echo "   • 🔐 Full sign-in support"
echo "   • 🕸️ Web scraping for new stations"
echo "   • 🔑 KWallet cookie storage"
echo "   • 🇬🇧 UK theming with Union Jack"
echo "   • 💎 Enhanced premium metadata"
echo ""
echo "🚀 To install:"
echo "   cd ${PACKAGE_NAME}"
echo "   ./install.sh"
echo ""
echo "📦 To create zip:"
echo "   zip -r ${PACKAGE_NAME}.zip ${PACKAGE_NAME}/"#!/usr/bin/env bash
# Global Player UK Package Generator (Original Version)
set -euo pipefail

PACKAGE_NAME="Global-Player-UK"
PLASMOID_ID="org.mooheda.globalplayer"

echo "[+] Creating Global Player UK package for Plasma 6..."

# Create directory structure
mkdir -p "${PACKAGE_NAME}"
mkdir -p "${PACKAGE_NAME}/${PLASMOID_ID}/contents/ui"
mkdir -p "${PACKAGE_NAME}/globalplayer-daemon"

cd "${PACKAGE_NAME}"

echo "[+] Creating metadata.json for UK version..."
cat > "${PLASMOID_ID}/metadata.json" << 'EOF'
{
    "KPlugin": {
        "Authors": [
            {
                "Email": "",
                "Name": "X-Seti (Mooheda)"
            }
        ],
        "Category": "Multimedia",
        "Description": "Listen to Global Player stations (Heart, Capital, Classic FM, LBC, etc.)",
        "Icon": "audio-headphones",
        "Id": "org.mooheda.globalplayer",
        "Name": "Global Player",
        "Version": "3.2",
        "Website": "",
        "BugReportUrl": ""
    },
    "X-Plasma-API-Minimum-Version": "6.0",
    "KPackageStructure": "Plasma/Applet"
}
EOF

echo "[+] Creating main.qml (UK version)..."
cat > "${PLASMOID_ID}/contents/ui/main.qml" << 'EOF'
// X-Seti - Aug12 2025 - Global Player UK - Plasma 6
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.kirigami 2.20 as Kirigami
import org.kde.notification 1.0

PlasmoidItem {
    id: root

    property var stationsModel: []
    property int stationIndex: 0
    property string selectedStation: stationsModel.length > 0 ? stationsModel[stationIndex] : ""
    property string nowArtist: ""
    property string nowTitle: ""
    property string nowShow: ""
    property string playState: "Stopped"
    property bool loggingEnabled: false
    property url artworkUrl: ""
    property string lastTrackId: ""
    property bool notificationsEnabled: true

    Plasmoid.icon: {
        if (artworkUrl.toString() !== "" && playState === "Playing") {
            return artworkUrl.toString()
        } else {
            return "audio-headphones"
        }
    }

    toolTipMainText: {
        if (playState === "Playing" && (nowArtist || nowTitle)) {
            return nowArtist && nowTitle ? (nowArtist + " — " + nowTitle) : (nowTitle || nowArtist)
        } else {
            return "Global Player"
        }
    }
    
    toolTipSubText: {
        if (playState === "Playing" && selectedStation) {
            return "Playing on " + selectedStation
        } else {
            return playState
        }
    }

    Timer {
        id: pollTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: getNowPlaying()
    }

    Notification {
        id: trackNotification
        componentName: "globalplayer"
        eventId: "trackChanged"
        title: "Global Player"
        iconName: "audio-headphones"
        flags: Notification.CloseOnTimeout
        property bool ready: false
        Component.onCompleted: ready = true
    }

    P5Support.DataSource {
        id: execDS
        engine: "executable"
        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim()
            if (sourceName.indexOf("GetNowPlaying") !== -1) {
                try {
                    var m = JSON.parse(out)
                    var newArtist = m.artist || ""
                    var newTitle = m.title || ""
                    var newShow = m.show || ""
                    var newState = m.state || playState
                    var newArtworkPath = m.artworkPath || ""
                    
                    var newTrackId = newArtist + "|" + newTitle
                    var trackChanged = (newTrackId !== lastTrackId) && newTrackId !== "|" && newState === "Playing"
                    
                    nowArtist = newArtist
                    nowTitle = newTitle
                    nowShow = newShow
                    playState = newState
                    
                    if (newArtworkPath) {
                        artworkUrl = "file://" + newArtworkPath
                    } else {
                        artworkUrl = ""
                    }
                    
                    if (trackChanged && notificationsEnabled && trackNotification.ready) {
                        showTrackNotification(newArtist, newTitle, selectedStation)
                        lastTrackId = newTrackId
                    } else if (!trackChanged && newTrackId !== "|") {
                        lastTrackId = newTrackId
                    }
                    
                } catch (e) {
                    console.log("Error parsing GetNowPlaying:", e)
                }
            } else if (sourceName.indexOf("GetState") !== -1) {
                try {
                    var s = JSON.parse(out)
                    playState = s.state || playState
                    loggingEnabled = s.logging === true
                    var st = s.station || ""
                    if (st.length > 0 && stationsModel.indexOf(st) >= 0) {
                        stationIndex = stationsModel.indexOf(st)
                    }
                } catch (e) {}
            } else if (sourceName.indexOf("GetStations") !== -1) {
                try {
                    var arr = JSON.parse(out)
                    if (Array.isArray(arr)) {
                        stationsModel = arr
                        if (arr.length > 0 && stationIndex >= arr.length) {
                            stationIndex = 0
                        }
                    }
                } catch (e) {}
            }
            disconnectSource(sourceName)
        }
    }

    function qdbusCall(method, args) {
        var cmd = "qdbus org.mooheda.gpd /org/mooheda/gpd org.mooheda.gpd1." + method
        if (args && args.length > 0) {
            for (var i = 0; i < args.length; ++i) {
                var a = ("" + args[i]).replace(/\"/g, "\\\"")
                cmd += " \"" + a + "\""
            }
        }
        execDS.connectSource(cmd)
    }

    function showTrackNotification(artist, title, station) {
        if (!trackNotification.ready) return
        
        var notificationText = ""
        if (artist && title) {
            notificationText = artist + " — " + title
        } else if (title) {
            notificationText = title
        } else {
            return
        }
        
        trackNotification.text = notificationText
        if (station) {
            trackNotification.text += "\nOn " + station
        }
        
        if (artworkUrl.toString() !== "") {
            trackNotification.iconName = artworkUrl.toString()
        } else {
            trackNotification.iconName = "audio-headphones"
        }
        
        trackNotification.sendEvent()
    }

    function getNowPlaying() { qdbusCall("GetNowPlaying", []) }
    function getState()      { qdbusCall("GetState", []) }
    function refreshStations(){ qdbusCall("GetStations", []) }
    function signIn()        { qdbusCall("SignIn", []) }

    function playCurrent() {
        if (stationsModel.length === 0) return
        selectedStation = stationsModel[stationIndex]
        qdbusCall("Play", [selectedStation])
        pollTimer.start()
        getState()
        getNowPlaying()
    }
    
    function nextStation() {
        if (stationsModel.length === 0) return
        stationIndex = (stationIndex + 1) % stationsModel.length
        playCurrent()
    }
    
    function prevStation() {
        if (stationsModel.length === 0) return
        stationIndex = (stationIndex - 1 + stationsModel.length) % stationsModel.length
        playCurrent()
    }

    Component.onCompleted: {
        refreshStations()
        getState()
        pollTimer.start()
    }

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "🇬🇧 Global Player v3.2"
                font.bold: true
                Layout.fillWidth: true
            }
            PC3.Button { 
                text: "Sign In"
                onClicked: signIn() 
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                radius: Kirigami.Units.smallSpacing
                border.color: Kirigami.Theme.textColor
                border.width: 1
                color: "transparent"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    source: artworkUrl
                    visible: artworkUrl.toString() !== ""
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
                
                PC3.Label {
                    anchors.centerIn: parent
                    text: artworkUrl.toString() === "" ? "🇬🇧" : ""
                    opacity: 0.6
                    font.pointSize: Math.max(16, Kirigami.Theme.defaultFont.pointSize * 1.5)
                }
                
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 2
                    width: 8
                    height: 8
                    radius: 4
                    color: playState === "Playing" ? "#0066cc" : "transparent"
                    visible: playState === "Playing"
                    
                    SequentialAnimation on opacity {
                        running: playState === "Playing"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                
                PC3.Label {
                    Layout.fillWidth: true
                    text: {
                        if (nowArtist && nowTitle) {
                            return nowArtist + " — " + nowTitle
                        } else if (nowTitle) {
                            return nowTitle
                        } else {
                            return "No track info"
                        }
                    }
                    wrapMode: Text.WordWrap
                    font.weight: Font.Medium
                }
                
                PC3.Label {
                    Layout.fillWidth: true
                    text: nowShow ? ("Show: " + nowShow) : ""
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                    visible: nowShow !== ""
                }
            }
        }

        PC3.ComboBox {
            id: stationPicker
            Layout.fillWidth: true
            model: stationsModel
            currentIndex: Math.max(0, Math.min(stationIndex, stationsModel.length - 1))
            
            onActivated: function(index) {
                if (index >= 0 && index < stationsModel.length) {
                    stationIndex = index
                    playCurrent()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            
            PC3.Button { 
                text: "◀"
                enabled: stationsModel.length > 1
                onClicked: prevStation() 
            }
            PC3.Button { 
                text: "Play"
                enabled: stationsModel.length > 0
                onClicked: playCurrent() 
            }
            PC3.Button { 
                text: "Pause"
                enabled: playState === "Playing"
                onClicked: qdbusCall("Pause", []) 
            }
            PC3.Button { 
                text: "▶"
                enabled: stationsModel.length > 1
                onClicked: nextStation() 
            }
            
            PC3.Label {
                text: playState
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                opacity: 0.7
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            
            PC3.CheckBox {
                id: logToggle
                text: "Log to ~/globalplayer/gp.logs"
                checked: loggingEnabled
                onToggled: qdbusCall("SetLogging", [checked ? "true" : "false"])
            }
            
            PC3.CheckBox {
                id: notifyToggle
                text: "Show notifications"
                checked: notificationsEnabled
                onToggled: notificationsEnabled = checked
            }
            
            PC3.Button { 
                text: "↻"
                onClicked: refreshStations()
                PC3.ToolTip.text: "Refresh station list"
            }
        }
    }

    compactRepresentation: Item {
        MouseArea {
            id: compactMouseArea
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
            
            onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0) {
                    prevStation()
                } else {
                    nextStation()
                }
                wheel.accepted = true
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: parent.height - Kirigami.Units.smallSpacing * 2
                    Layout.preferredHeight: parent.height - Kirigami.Units.smallSpacing * 2
                    Layout.alignment: Qt.AlignCenter
                    radius: Kirigami.Units.smallSpacing
                    border.color: Kirigami.Theme.textColor
                    border.width: 1
                    color: "transparent"
                    
                    Image { 
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectFit
                        source: artworkUrl
                        visible: artworkUrl.toString() !== ""
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 300 }
                        }
                    }
                    
                    PC3.Label {
                        anchors.centerIn: parent
                        text: artworkUrl.toString() === "" ? "🇬🇧" : ""
                        opacity: 0.6
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: 4
                        height: 4
                        radius: 2
                        color: playState === "Playing" ? "#0066cc" : "transparent"
                        visible: playState === "Playing"
                        
                        SequentialAnimation on opacity {
                            running: playState === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: {
                        if (stationsModel.length > 0 && stationIndex >= 0 && stationIndex < stationsModel.length) {
                            return stationsModel[stationIndex]
                        } else {
                            return "Global Player"
                        }
                    }
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        PC3.Menu {
            id: stationMenu
            
            Repeater {
                model: stationsModel
                delegate: PC3.MenuItem {
                    required property int index
                    required property string modelData
                    
                    text: modelData
                    checkable: true
                    checked: index === stationIndex
                    onTriggered: { 
                        stationIndex = index
                        playCurrent() 
                    }
                }
            }
            
            PC3.MenuSeparator {
                visible: stationsModel.length > 0
            }
            
            PC3.MenuItem { 
                text: "Play"
                enabled: stationsModel.length > 0
                onTriggered: playCurrent() 
            }
            PC3.MenuItem { 
                text: "Pause"
                enabled: playState === "Playing"
                onTriggered: qdbusCall("Pause", []) 
            }
            PC3.MenuSeparator {}
            PC3.MenuItem { 
                text: notificationsEnabled ? "Disable Notifications" : "Enable Notifications"
                onTriggered: notificationsEnabled = !notificationsEnabled
            }
            PC3.MenuItem { 
                text: loggingEnabled ? "Disable Logging" : "Enable Logging"
                onTriggered: qdbusCall("SetLogging", [(!loggingEnabled).toString()]) 
            }
            PC3.MenuItem { 
                text: "Refresh Stations"
                onTriggered: refreshStations() 
            }
            PC3.MenuItem { 
                text: "Sign In"
                onTriggered: signIn() 
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: stationMenu.open()
        }
    }
}
EOF

echo "[+] Creating UK station list (original Global Player stations)..."
cat > "globalplayer-daemon/stations_static.json" << 'EOF'
[
  {
    "name": "Classic FM",
    "url": "https://media-ssl.musicradio.com/ClassicFM"
  },
  {
    "name": "Classic FM Relax",
    "url": "https://media-ssl.musicradio.com/ClassicFMRelax"
  },
  {
    "name": "Heart",
    "url": "https://media-ssl.musicradio.com/HeartUK"
  },
  {
    "name": "Heart London",
    "url": "https://media-ssl.musicradio.com/HeartLondon"
  },
  {
    "name": "Heart 60s",
    "url": "https://media-ssl.musicradio.com/Heart60s"
  },
  {
    "name": "Heart 70s",
    "url": "https://media-ssl.musicradio.com/Heart70s"
  },
  {
    "name": "Heart 80s",
    "url": "https://media-ssl.musicradio.com/Heart80s"
  },
  {
    "name": "Heart 90s",
    "url": "https://media-ssl.musicradio.com/Heart90s"
  },
  {
    "name": "Heart 00s",
    "url": "https://media-ssl.musicradio.com/Heart00s"
  },
  {
    "name": "Heart Dance",
    "url": "https://media-ssl.musicradio.com/HeartDance"
  },
  {
    "name": "Heart Xmas",
    "url": "https://media-ssl.musicradio.com/HeartXmas"
  },
  {
    "name": "Capital",
    "url": "https://media-ssl.musicradio.com/CapitalUK"
  },
  {
    "name": "Capital London",
    "url": "https://media-ssl.musicradio.com/CapitalLondon"
  },
  {
    "name": "Capital Dance",
    "url": "https://media-ssl.musicradio.com/CapitalDance"
  },
  {
    "name": "Capital XTRA",
    "url": "https://media-ssl.musicradio.com/CapitalXTRA"
  },
  {
    "name": "Capital XTRA Reloaded",
    "url": "https://media-ssl.musicradio.com/CapitalXTRA-Reloaded"
  },
  {
    "name": "LBC",
    "url": "https://media-ssl.musicradio.com/LBCUK"
  },
  {
    "name": "LBC News",
    "url": "https://media-ssl.musicradio.com/LBCNewsUK"
  },
  {
    "name": "Smooth",
    "url": "https://media-ssl.musicradio.com/SmoothUK"
  },
  {
    "name": "Smooth London",
    "url": "https://media-ssl.musicradio.com/SmoothLondon"
  },
  {
    "name": "Smooth Chill",
    "url": "https://media-ssl.musicradio.com/SmoothChill"
  },
  {
    "name": "Smooth Country",
    "url": "https://media-ssl.musicradio.com/SmoothCountry"
  },
  {
    "name": "Radio X",
    "url": "https://media-ssl.musicradio.com/RadioXUK"
  },
  {
    "name": "Radio X Classic Rock",
    "url": "https://media-ssl.musicradio.com/RadioXClassicRock"
  },
  {
    "name": "Gold",
    "url": "https://media-ssl.musicradio.com/Gold"
  }
]
EOF

echo "[+] Creating UK daemon (original with web scraping)..."
cat > "globalplayer-daemon/gpd.py" << 'EOF'
#!/usr/bin/env python3
#X-Seti (Mooheda)- Aug12 2025 - GlobalPlayer UK - Plasma 6 Compatible
import os, json, time, re, hashlib, pathlib, threading, subprocess, tempfile
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

CONFIG_DIR = os.path.expanduser("~/.config/globalplayer")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
CACHE_DIR = os.path.expanduser("~/.cache/globalplayer")
ARTWORK_DIR = os.path.join(CACHE_DIR, "artwork")
LOG_DIR = os.path.expanduser("~/globalplayer")
LOG_FILE = os.path.join(LOG_DIR, "gp.logs")
STATIC_STATIONS_FILE = os.path.join(os.path.dirname(__file__), "stations_static.json")

from playback_mpv import MPVPlayer

def ensure_dirs():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)
    os.makedirs(ARTWORK_DIR, exist_ok=True)

def load_cfg():
    ensure_dirs()
    if os.path.exists(CONFIG_FILE):
        try:
            return json.load(open(CONFIG_FILE))
        except Exception:
            pass
    return {"lastStation": "", "logging": False, "tokenStored": False}

def save_cfg(cfg):
    ensure_dirs()
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)

def kwallet_store(key, value):
    for cmd in [
        ["kwalletcli6", "-f", "GlobalPlayer", "-e", key, "-v", value],
        ["kwalletcli5", "-f", "GlobalPlayer", "-e", key, "-v", value],
        ["kwalletcli", "-f", "GlobalPlayer", "-e", key, "-v", value],
    ]:
        try:
            p = subprocess.run(cmd, capture_output=True)
            if p.returncode == 0: return True
        except Exception:
            pass
    try:
        p = subprocess.run(["kwallet-query", "-w", "GlobalPlayer", "-f", "GlobalPlayer", key], input=value.encode(), capture_output=True)
        return p.returncode == 0
    except Exception:
        pass
    return False

def kwallet_read(key):
    for cmd in [["kwalletcli6","-f","GlobalPlayer","-r",key],
                ["kwalletcli5","-f","GlobalPlayer","-r",key],
                ["kwalletcli","-f","GlobalPlayer","-r",key]]:
        try:
            p = subprocess.run(cmd, capture_output=True, text=True)
            if p.returncode == 0:
                return p.stdout.strip()
        except Exception:
            continue
    return ""

def http_get(url, headers=None, timeout=10):
    try:
        import requests
        r = requests.get(url, headers=headers or {}, timeout=timeout)
        if r.status_code == 200:
            return r.text
    except Exception:
        pass
    return ""

def http_get_json(url, headers=None, timeout=10):
    try:
        import requests
        r = requests.get(url, headers=headers or {}, timeout=timeout)
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None

def http_get_binary(url, headers=None, timeout=10):
    try:
        import requests
        r = requests.get(url, headers=headers or {}, timeout=timeout)
        if r.status_code == 200:
            return r.content
    except Exception:
        pass
    return None

def discover_stations():
    # Merge static list with scraped list (best-effort)
    stations = {}
    # static first
    try:
        with open(STATIC_STATIONS_FILE, "r") as f:
            for s in json.load(f):
                stations[s["name"]] = s["url"]
    except Exception:
        pass

    # Try to scrape additional stations from globalplayer.com
    html = http_get("https://www.globalplayer.com/live/")
    if html:
        slugs = set(re.findall(r"/live/([a-z0-9\-]+)/", html))
        for slug in sorted(slugs):
            parts = slug.split("-")
            host_key = "".join([p.capitalize() for p in parts])
            candidate = f"https://media-ssl.musicradio.com/{host_key}"
            stations.setdefault(" ".join([p.capitalize() for p in parts]), candidate)

    return dict(sorted(stations.items(), key=lambda kv: kv[0].lower()))

def artwork_for(artist, title):
    if not (artist or title):
        return ""
    key = f"{artist}|{title}".lower().strip()
    h = hashlib.sha1(key.encode()).hexdigest()
    path = os.path.join(ARTWORK_DIR, h + ".jpg")
    if os.path.exists(path):
        return path
    # iTunes Search as best-effort
    q = (artist + " " + title).strip()
    if not q:
        return ""
    import urllib.parse
    url = "https://itunes.apple.com/search?entity=song&limit=1&term=" + urllib.parse.quote(q)
    data = http_get_json(url)
    if data and data.get("results"):
        art = data["results"][0].get("artworkUrl100") or data["results"][0].get("artworkUrl60")
        if art:
            art = art.replace("100x100bb.jpg", "300x300bb.jpg").replace("60x60bb.jpg", "300x300bb.jpg")
            blob = http_get_binary(art)
            if blob:
                with open(path, "wb") as f:
                    f.write(blob)
                return path
    return ""

class GlobalPlayerDaemon(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, '/org/mooheda/gpd')
        ensure_dirs()
        self.cfg = load_cfg()
        self.player = MPVPlayer()
        self.station = self.cfg.get("lastStation") or ""
        self.logging = bool(self.cfg.get("logging", False))
        self.stations = discover_stations()
        self.cookies = kwallet_read("cookies") or ""
        self._md_lock = threading.Lock()
        self._last_track_id = ""

    @dbus.service.method("org.mooheda.gpd1", in_signature="s")
    def Play(self, stationName):
        url = self.stations.get(stationName)
        if not url:
            return
        self.station = stationName
        self.player.play(url)
        self._log_event(f"Play station={stationName}")
        self.cfg["lastStation"] = stationName
        save_cfg(self.cfg)

    @dbus.service.method("org.mooheda.gpd1")
    def Pause(self):
        self.player.pause()
        self._log_event("Pause")

    @dbus.service.method("org.mooheda.gpd1")
    def Resume(self):
        self.player.resume()
        self._log_event("Resume")

    @dbus.service.method("org.mooheda.gpd1", in_signature="b")
    def SetLogging(self, enabled):
        self.logging = bool(enabled)
        self.cfg["logging"] = self.logging
        save_cfg(self.cfg)
        self._log_event(f"Logging enabled={self.logging}")

    @dbus.service.method("org.mooheda.gpd1", out_signature="s")
    def GetNowPlaying(self):
        md = self.player.get_metadata() or {}
        artist = ""
        title = ""
        show = ""

        # Try common metadata keys
        if "artist" in md and "title" in md:
            artist = md.get("artist") or ""
            title = md.get("title") or ""
        elif "icy-title"