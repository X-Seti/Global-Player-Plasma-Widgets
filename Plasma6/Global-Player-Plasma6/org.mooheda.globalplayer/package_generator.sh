#!/usr/bin/env bash
# Global Player Plasma 6 Package Generator
# Run this script to create the complete package structure

set -euo pipefail

PACKAGE_NAME="Global-Player-Plasma6"
PLASMOID_ID="org.mooheda.globalplayer"

echo "[+] Creating Global Player Plasma 6 package structure..."

# Create directory structure
mkdir -p "${PACKAGE_NAME}"
mkdir -p "${PACKAGE_NAME}/${PLASMOID_ID}/contents/ui"
mkdir -p "${PACKAGE_NAME}/globalplayer-daemon"

cd "${PACKAGE_NAME}"

echo "[+] Creating metadata.json..."
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
        "Description": "Listen to Global Player stations (dynamic + static list)",
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

echo "[+] Creating main.qml..."
cat > "${PLASMOID_ID}/contents/ui/main.qml" << 'EOF'
// X-Seti - Aug12 2025 - GlobalPlayer - Plasma 6 Compatible
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as P5Support

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

    // Poll metadata every 10s
    Timer {
        id: pollTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            getNowPlaying()
        }
    }

    P5Support.DataSource {
        id: execDS
        engine: "executable"
        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim()
            if (sourceName.indexOf("GetNowPlaying") !== -1) {
                try {
                    var m = JSON.parse(out)
                    nowArtist = m.artist || ""
                    nowTitle  = m.title || ""
                    nowShow   = m.show || ""
                    playState = m.state || playState
                    if (m.artworkPath) {
                        artworkUrl = "file://" + m.artworkPath
                    }
                } catch (e) {}
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
                    stationsModel = arr
                    if (arr.length > 0 && stationIndex >= arr.length) stationIndex = 0
                } catch (e) {}
            }
            disconnectSource(sourceName)
        }
    }

    function qdbusCall(method, args) {
        var cmd = "qdbus org.mooheda.gpd /org/mooheda/gpd org.mooheda.gpd1." + method
        if (args && args.length > 0) {
            for (var i=0; i<args.length; ++i) {
                var a = (""+args[i]).replace(/\"/g, "\\\"")
                cmd += " \"" + a + "\""
            }
        }
        execDS.connectSource(cmd)
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

    // Full widget representation
    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        anchors.margins: PlasmaCore.Units.smallSpacing
        spacing: PlasmaCore.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Global Player v3.2"
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
            spacing: PlasmaCore.Units.smallSpacing
            
            Rectangle {
                width: PlasmaCore.Units.gridUnit * 4
                height: PlasmaCore.Units.gridUnit * 4
                radius: PlasmaCore.Units.smallSpacing
                border.color: PlasmaCore.Theme.textColor
                border.width: 1
                color: "transparent"
                
                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    source: artworkUrl
                    visible: artworkUrl !== ""
                }
                
                PC3.Label {
                    anchors.centerIn: parent
                    text: artworkUrl === "" ? "♪" : ""
                    opacity: 0.6
                    font.pointSize: PlasmaCore.Theme.defaultFont.pointSize * 2
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: PlasmaCore.Units.smallSpacing
                
                PC3.Label {
                    Layout.fillWidth: true
                    text: (nowArtist || nowTitle) ? (nowArtist + " — " + nowTitle) : "No track info"
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
            currentIndex: stationIndex
            onActivated: {
                stationIndex = currentIndex
                playCurrent()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing
            
            PC3.Button { 
                text: "◀"
                onClicked: prevStation() 
            }
            PC3.Button { 
                text: "Play"
                onClicked: playCurrent() 
            }
            PC3.Button { 
                text: "Pause"
                onClicked: qdbusCall("Pause", []) 
            }
            PC3.Button { 
                text: "▶"
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
            spacing: PlasmaCore.Units.smallSpacing
            
            PC3.CheckBox {
                id: logToggle
                text: "Log to ~/globalplayer/gp.logs"
                checked: loggingEnabled
                onToggled: qdbusCall("SetLogging", [checked ? "true" : "false"])
            }
            
            PC3.Button { 
                text: "↻"
                onClicked: refreshStations()
                PC3.ToolTip.text: "Refresh station list"
            }
        }
    }

    // Compact panel representation
    compactRepresentation: Item {
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 12
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 2

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: PlasmaCore.Units.smallSpacing
                spacing: PlasmaCore.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: parent.height - PlasmaCore.Units.smallSpacing * 2
                    Layout.preferredHeight: parent.height - PlasmaCore.Units.smallSpacing * 2
                    radius: PlasmaCore.Units.smallSpacing
                    border.color: PlasmaCore.Theme.textColor
                    border.width: 1
                    color: "transparent"
                    
                    Image { 
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectFit
                        source: artworkUrl
                        visible: artworkUrl !== ""
                    }
                    
                    PC3.Label {
                        anchors.centerIn: parent
                        text: artworkUrl === "" ? "♪" : ""
                        opacity: 0.6
                    }
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: stationsModel.length > 0 ? stationsModel[stationIndex] : "Global Player"
                    elide: Text.ElideRight
                }
            }
        }

        // Context menu
        PC3.Menu {
            id: stationMenu
            
            Repeater {
                model: stationsModel
                delegate: PC3.MenuItem {
                    text: modelData
                    checkable: true
                    checked: index === stationIndex
                    onTriggered: { 
                        stationIndex = index
                        playCurrent() 
                    }
                }
            }
            
            PC3.MenuSeparator {}
            PC3.MenuItem { text: "Play"; onTriggered: playCurrent() }
            PC3.MenuItem { text: "Pause"; onTriggered: qdbusCall("Pause", []) }
            PC3.MenuItem { 
                text: loggingEnabled ? "Disable Logging" : "Enable Logging"
                onTriggered: qdbusCall("SetLogging", [(!loggingEnabled).toString()]) 
            }
            PC3.MenuItem { text: "Refresh Stations"; onTriggered: refreshStations() }
            PC3.MenuItem { text: "Sign In"; onTriggered: signIn() }
        }

        // Right-click context menu
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: stationMenu.open()
        }
    }
}
EOF

echo "[+] Creating daemon (gpd.py)..."
cat > "globalplayer-daemon/gpd.py" << 'EOF'
#!/usr/bin/env python3
#X-Seti (Mooheda)- Aug12 2025 - GlobalPlayer - Plasma 6 Compatible
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
        # Launch a Qt6 WebEngine view to login and capture cookies for *.globalplayer.com
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

echo "[+] Creating MPV player (playback_mpv.py)..."
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
        # Query MPV for 'metadata' property
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

echo "[+] Creating stations list (stations_static.json)..."
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

echo "[+] Creating systemd service (gpd.service)..."
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
EOF

echo "[+] Creating uninstall script..."
cat > "uninstall.sh" << 'EOF'
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
EOF

echo "[+] Creating README..."
cat > "README.md" << 'EOF'
# Global Player Plasma 6 Widget

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
EOF

# Make scripts executable
chmod +x install.sh uninstall.sh

cd ..

echo ""
echo "✓ Package created successfully!"
echo "📁 Directory: ${PACKAGE_NAME}/"
echo ""
echo "📋 Contents:"
echo "   ├── ${PLASMOID_ID}/"
echo "   │   ├── metadata.json"
echo "   │   └── contents/ui/main.qml"
echo "   ├── globalplayer-daemon/"
echo "   │   ├── gpd.py"
echo "   │   ├── playback_mpv.py"
echo "   │   └── stations_static.json"
echo "   ├── install.sh"
echo "   ├── uninstall.sh"
echo "   ├── gpd.service"
echo "   └── README.md"
echo ""
echo "🚀 To install:"
echo "   cd ${PACKAGE_NAME}"
echo "   ./install.sh"
echo ""
echo "📦 To create a zip archive:"
echo "   zip -r ${PACKAGE_NAME}.zip ${PACKAGE_NAME}/"