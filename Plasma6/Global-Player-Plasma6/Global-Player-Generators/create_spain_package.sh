#!/usr/bin/env bash
# Global Player Spain Package Generator
set -euo pipefail

PACKAGE_NAME="Global-Player-Spain"
PLASMOID_ID="org.mooheda.globalplayer.spain"

echo "[+] Creating Global Player España package for Plasma 6..."

# Create directory structure
mkdir -p "${PACKAGE_NAME}"
mkdir -p "${PACKAGE_NAME}/${PLASMOID_ID}/contents/ui"
mkdir -p "${PACKAGE_NAME}/globalplayer-daemon"

cd "${PACKAGE_NAME}"

echo "[+] Creating metadata.json for Spain version..."
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
        "Description": "Escucha emisoras de radio españolas (Cadena SER, Los 40, Europa FM, etc.)",
        "Icon": "audio-headphones",
        "Id": "org.mooheda.globalplayer.spain",
        "Name": "Global Player España",
        "Version": "3.2",
        "Website": "",
        "BugReportUrl": ""
    },
    "X-Plasma-API-Minimum-Version": "6.0",
    "KPackageStructure": "Plasma/Applet"
}
EOF

echo "[+] Creating main.qml (Spain version)..."
cat > "${PLASMOID_ID}/contents/ui/main.qml" << 'EOF'
// X-Seti - Aug12 2025 - Global Player España - Plasma 6
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
            return "Global Player España"
        }
    }
    
    toolTipSubText: {
        if (playState === "Playing" && selectedStation) {
            return "Sonando en " + selectedStation
        } else {
            return playState === "Playing" ? "Reproduciendo" : playState === "Paused" ? "Pausado" : "Parado"
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
        componentName: "globalplayer-spain"
        eventId: "trackChanged"
        title: "Global Player España"
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
        var cmd = "qdbus org.mooheda.gpd.spain /org/mooheda/gpd org.mooheda.gpd1." + method
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
            trackNotification.text += "\nEn " + station
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
                text: "🇪🇸 Global Player España v3.2"
                font.bold: true
                Layout.fillWidth: true
            }
            PC3.Button { 
                text: "Iniciar Sesión"
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
                    text: artworkUrl.toString() === "" ? "🇪🇸" : ""
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
                    color: playState === "Playing" ? "#c60b1e" : "transparent"
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
                            return "Sin información de pista"
                        }
                    }
                    wrapMode: Text.WordWrap
                    font.weight: Font.Medium
                }
                
                PC3.Label {
                    Layout.fillWidth: true
                    text: nowShow ? ("Programa: " + nowShow) : ""
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
                text: "Reproducir"
                enabled: stationsModel.length > 0
                onClicked: playCurrent() 
            }
            PC3.Button { 
                text: "Pausa"
                enabled: playState === "Playing"
                onClicked: qdbusCall("Pause", []) 
            }
            PC3.Button { 
                text: "▶"
                enabled: stationsModel.length > 1
                onClicked: nextStation() 
            }
            
            PC3.Label {
                text: {
                    if (playState === "Playing") return "Reproduciendo"
                    if (playState === "Paused") return "Pausado" 
                    return "Parado"
                }
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
                text: "Log a ~/globalplayer/gp-spain.logs"
                checked: loggingEnabled
                onToggled: qdbusCall("SetLogging", [checked ? "true" : "false"])
            }
            
            PC3.CheckBox {
                id: notifyToggle
                text: "Notificaciones"
                checked: notificationsEnabled
                onToggled: notificationsEnabled = checked
            }
            
            PC3.Button { 
                text: "↻"
                onClicked: refreshStations()
                PC3.ToolTip.text: "Actualizar lista de emisoras"
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
                        text: artworkUrl.toString() === "" ? "🇪🇸" : ""
                        opacity: 0.6
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: 4
                        height: 4
                        radius: 2
                        color: playState === "Playing" ? "#c60b1e" : "transparent"
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
                            return "Global Player España"
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
                text: "Reproducir"
                enabled: stationsModel.length > 0
                onTriggered: playCurrent() 
            }
            PC3.MenuItem { 
                text: "Pausa"
                enabled: playState === "Playing"
                onTriggered: qdbusCall("Pause", []) 
            }
            PC3.MenuSeparator {}
            PC3.MenuItem { 
                text: notificationsEnabled ? "Desactivar Notificaciones" : "Activar Notificaciones"
                onTriggered: notificationsEnabled = !notificationsEnabled
            }
            PC3.MenuItem { 
                text: loggingEnabled ? "Desactivar Logging" : "Activar Logging"
                onTriggered: qdbusCall("SetLogging", [(!loggingEnabled).toString()]) 
            }
            PC3.MenuItem { 
                text: "Actualizar Emisoras"
                onTriggered: refreshStations() 
            }
            PC3.MenuItem { 
                text: "Iniciar Sesión"
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

echo "[+] Creating Spain station list..."
cat > "globalplayer-daemon/stations_static.json" << 'EOF'
[
  {
    "name": "Cadena SER",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENASER.mp3"
  },
  {
    "name": "Los 40",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/LOS40.mp3"
  },
  {
    "name": "Europa FM",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/EUROPAFM.mp3"
  },
  {
    "name": "Cadena 100",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENA100.mp3"
  },
  {
    "name": "KISS FM",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/KISSFM.mp3"
  },
  {
    "name": "Radio Nacional",
    "url": "https://rtvehlsvodlive.akamaized.net/segments/rne/rne1/rne1_main.m3u8"
  },
  {
    "name": "RNE Radio 3",
    "url": "https://rtvehlsvodlive.akamaized.net/segments/rne/rne3/rne3_main.m3u8"
  },
  {
    "name": "Radio Clásica",
    "url": "https://rtvehlsvodlive.akamaized.net/segments/rne/rnec/rnec_main.m3u8"
  },
  {
    "name": "Onda Cero",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/ONDACERO.mp3"
  },
  {
    "name": "COPE",
    "url": "https://flucast-b02-06.flumotion.com/cope/net1.mp3"
  },
  {
    "name": "Rock FM",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/ROCKFM.mp3"
  },
  {
    "name": "Mega Star FM",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/MEGASTAR.mp3"
  },
  {
    "name": "Radio Marca",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIOMARCA_SC"
  },
  {
    "name": "esRadio",
    "url": "https://libertaddigital-radio-live1.flumotion.com/libertaddigital/ld-live1-low.mp3"
  },
  {
    "name": "Cadena Dial",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/CADENADIAL.mp3"
  },
  {
    "name": "Máxima FM",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/MAXIMAFM.mp3"
  },
  {
    "name": "ABC Punto Radio",
    "url": "https://flucast-b02-06.flumotion.com/abc/net2.mp3"
  },
  {
    "name": "Radio Olé",
    "url": "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIOOLE.mp3"
  }
]
EOF

echo "[+] Creating Spain daemon..."
cat > "globalplayer-daemon/gpd.py" << 'EOF'
#!/usr/bin/env python3
#X-Seti (Mooheda)- Aug12 2025 - GlobalPlayer España - Plasma 6 Compatible
import os, json, time, re, hashlib, pathlib, threading, subprocess, tempfile
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

CONFIG_DIR = os.path.expanduser("~/.config/globalplayer-spain")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
CACHE_DIR = os.path.expanduser("~/.cache/globalplayer-spain")
ARTWORK_DIR = os.path.join(CACHE_DIR, "artwork")
LOG_DIR = os.path.expanduser("~/globalplayer")
LOG_FILE = os.path.join(LOG_DIR, "gp-spain.logs")
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
    stations = {}
    try:
        with open(STATIC_STATIONS_FILE, "r") as f:
            for s in json.load(f):
                stations[s["name"]] = s["url"]
    except Exception:
        pass
    return dict(sorted(stations.items(), key=lambda kv: kv[0].lower()))

def artwork_for(artist, title):
    if not (artist or title):
        return ""
    key = f"{artist}|{title}".lower().strip()
    h = hashlib.sha1(key.encode()).hexdigest()
    path = os.path.join(ARTWORK_DIR, h + ".jpg")
    if os.path.exists(path):
        return path
    
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
        self._log_event("SignIn requested - not needed for most Spanish stations")

    def _log_event(self, text):
        ensure_dirs()
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{timestamp} | {text}\n")

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.mooheda.gpd.spain", bus)
    gpd = GlobalPlayerDaemon(bus)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
EOF

echo "[+] Creating MPV player..."
cat > "globalplayer-daemon/playback_mpv.py" << 'EOF'
#X-Seti - Aug12 2025 - GlobalPlayer
import os, json, socket, subprocess, threading, time, tempfile

class MPVPlayer:
    def __init__(self, socket_path=None):
        self.proc = None
        self.sock_path = socket_path or os.path.join(tempfile.gettempdir(), "gpd-spain-mpv.sock")
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
cat > "gpd-spain.service" << 'EOF'
[Unit]
Description=Global Player España Daemon v3.2

[Service]
Type=simple
ExecStart=/usr/bin/env python3 %h/globalplayer-daemon-spain/gpd.py
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "[+] Creating install script..."
cat > "install.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer.spain"
PLASMOID_SRC="$(dirname "$0")/${PLASMOID_ID}"
PLASMOID_DST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

DAEMON_SRC="$(dirname "$0")/globalplayer-daemon"
DAEMON_DST="${HOME}/globalplayer-daemon-spain"

echo "[+] Installing Global Player España para Plasma 6..."
echo ""
echo "🇪🇸 Emisoras Españolas:"
echo "   • Principales: Cadena SER, Los 40, Europa FM, Cadena 100, Kiss FM"
echo "   • Públicas: Radio Nacional, RNE Radio 3, Radio Clásica"
echo "   • Privadas: Onda Cero, COPE, Rock FM, Mega Star FM"
echo "   • Especializadas: Radio Marca, esRadio, Cadena Dial, Radio Olé"
echo ""
echo "[+] Dependencias necesarias:"
echo "    Arch:          sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests"
echo "    Debian/Ubuntu: sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests"
echo "    Fedora:        sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests"

echo "[+] Installing plasmoid to ${PLASMOID_DST}"
mkdir -p "${PLASMOID_DST}"
rsync -a --delete "${PLASMOID_SRC}/" "${PLASMOID_DST}/" || cp -rf "${PLASMOID_SRC}/." "${PLASMOID_DST}/"

echo "[+] Installing daemon to ${DAEMON_DST}"
mkdir -p "${DAEMON_DST}"
rsync -a --delete "${DAEMON_SRC}/" "${DAEMON_DST}/" || cp -rf "${DAEMON_SRC}/." "${DAEMON_DST}/"

echo "[+] Installing systemd --user service"
mkdir -p "${HOME}/.config/systemd/user"
cp "$(dirname "$0")/gpd-spain.service" "${HOME}/.config/systemd/user/gpd-spain.service"
systemctl --user daemon-reload || true
systemctl --user enable --now gpd-spain.service || true

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

echo "[+] Esperando a que los servicios se inicien..."
sleep 5

if systemctl --user is-active gpd-spain.service >/dev/null 2>&1; then
  echo "    ✓ El daemon de España está funcionando"
else
  echo "    ⚠ El daemon de España podría no estar funcionando. Comprueba: systemctl --user status gpd-spain.service"
fi

echo ""
echo "🇪🇸 ¡Global Player España instalado con éxito!"
echo ""
echo "📱 Para añadir widget:"
echo "   Clic derecho en panel → Añadir Widgets → Buscar 'Global Player España'"
EOF

echo "[+] Creating uninstall script..."
cat > "uninstall.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer.spain"

echo "[+] Desinstalando Global Player España..."

systemctl --user disable --now gpd-spain.service || true
rm -f "${HOME}/.config/systemd/user/gpd-spain.service"
systemctl --user daemon-reload || true

rm -rf "${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
rm -rf "${HOME}/globalplayer-daemon-spain"
rm -rf "${HOME}/.config/globalplayer-spain"
rm -rf "${HOME}/.cache/globalplayer-spain"

if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  systemctl --user restart plasma-plasmashell.service
else
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[✓] Global Player España completamente eliminado."
EOF

echo "[+] Creating README..."
cat > "README.md" << 'EOF'
# 🇪🇸 Global Player España - Plasma 6 Widget

Un widget de KDE Plasma 6 para emisoras de radio españolas con artwork de álbum y notificaciones.

## 📻 Emisoras Españolas

### Principales Cadenas
- **Cadena SER** - Líder en información y entretenimiento
- **Los 40** - Música actual y éxitos
- **Europa FM** - Pop y rock en español e inglés
- **Cadena 100** - Éxitos en español
- **Kiss FM** - Dance y electrónica

### Radio Pública (RTVE)
- **Radio Nacional** - Información y entretenimiento público
- **RNE Radio 3** - Música alternativa y cultura
- **Radio Clásica** - Música clásica y culta

### Otras Privadas
- **Onda Cero** - Información y entretenimiento
- **COPE** - Radio generalista
- **Rock FM** - Rock en español e internacional
- **Mega Star FM** - Éxitos de los 80, 90 y 2000

### Especializadas
- **Radio Marca** - Deportes
- **esRadio** - Información y debate
- **Cadena Dial** - Música en español
- **Máxima FM** - Dance y electrónica
- **ABC Punto Radio** - Información
- **Radio Olé** - Música flamenca y española

## ✨ Características
- 🎨 **Artwork de álbum** en icono del panel y notificaciones
- 🔔 **Notificaciones de escritorio** al cambiar canciones
- 🇪🇸 **Localización española** con bandera española y acentos rojos
- 🎛️ **Control con rueda del ratón** para cambiar emisoras en el panel
- 📝 **Registro** de pistas reproducidas
- 🌍 **Funciona globalmente** - sin restricciones geográficas

## 🚀 Instalación

1. **Instalar dependencias**:
   ```bash
   # Arch Linux
   sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests
   
   # Ubuntu/Debian
   sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests
   
   # Fedora
   sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests
   ```

2. **Instalar widget**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Añadir al panel**: Clic derecho en panel → Añadir Widgets → "Global Player España"

## 🔧 Detalles Técnicos
- **Servicio D-Bus**: `org.mooheda.gpd.spain`
- **Configuración**: `~/.config/globalplayer-spain/`
- **Caché**: `~/.cache/globalplayer-spain/`
- **Registros**: `~/globalplayer/gp-spain.logs`

## 🛠️ Solución de Problemas
- **Estado del servicio**: `systemctl --user status gpd-spain.service`
- **Ver registros**: `journalctl --user -u gpd-spain.service -f`
- **Reiniciar Plasma**: `systemctl --user restart plasma-plasmashell.service`

## 📜 Versión
v3.2 España - Compatible con Plasma 6
Creado por X-Seti (Mooheda) - Agosto 2025
EOF

chmod +x install.sh uninstall.sh

cd ..

echo ""
echo "🇪🇸 ¡Paquete Global Player España creado con éxito!"
echo ""
echo "📁 Paquete: ${PACKAGE_NAME}/"
echo ""
echo "📻 Emisoras Españolas:"
echo "   • Principales: Cadena SER, Los 40, Europa FM, Cadena 100, Kiss FM"
echo "   • Públicas: Radio Nacional, RNE Radio 3, Radio Clásica"
echo "   • Privadas: Onda Cero, COPE, Rock FM, Mega Star FM"
echo "   • Especializadas: Radio Marca, esRadio, Cadena Dial, Radio Olé"
echo ""
echo "✨ Características:"
echo "   • 🇪🇸 Bandera española y acentos rojos"
echo "   • 🔔 Localización en español"
echo "   • 🎨 Soporte de artwork de álbum"
echo "   • 📝 Registro en español"
echo ""
echo "🚀 Para instalar:"
echo "   cd ${PACKAGE_NAME}"
echo "   ./install.sh"
echo ""
echo "📦 Para crear zip:"
echo "   zip -r ${PACKAGE_NAME}.zip ${PACKAGE_NAME}/"