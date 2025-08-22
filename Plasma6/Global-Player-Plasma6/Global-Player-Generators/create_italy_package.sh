#!/usr/bin/env bash
# Global Player Italy Package Generator
set -euo pipefail

PACKAGE_NAME="Global-Player-Italy"
PLASMOID_ID="org.mooheda.globalplayer.italy"

echo "[+] Creating Global Player Italia package for Plasma 6..."

# Create directory structure
mkdir -p "${PACKAGE_NAME}"
mkdir -p "${PACKAGE_NAME}/${PLASMOID_ID}/contents/ui"
mkdir -p "${PACKAGE_NAME}/globalplayer-daemon"

cd "${PACKAGE_NAME}"

echo "[+] Creating metadata.json for Italy version..."
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
        "Description": "Ascolta le stazioni radio italiane (RTL 102.5, Radio Deejay, RDS, etc.)",
        "Icon": "audio-headphones",
        "Id": "org.mooheda.globalplayer.italy",
        "Name": "Global Player Italia",
        "Version": "3.2",
        "Website": "",
        "BugReportUrl": ""
    },
    "X-Plasma-API-Minimum-Version": "6.0",
    "KPackageStructure": "Plasma/Applet"
}
EOF

echo "[+] Creating main.qml (Italy version)..."
cat > "${PLASMOID_ID}/contents/ui/main.qml" << 'EOF'
// X-Seti - Aug12 2025 - Global Player Italia - Plasma 6
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
            return "Global Player Italia"
        }
    }
    
    toolTipSubText: {
        if (playState === "Playing" && selectedStation) {
            return "In riproduzione su " + selectedStation
        } else {
            return playState === "Playing" ? "In riproduzione" : playState === "Paused" ? "In pausa" : "Fermato"
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
        componentName: "globalplayer-italy"
        eventId: "trackChanged"
        title: "Global Player Italia"
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
        var cmd = "qdbus org.mooheda.gpd.italy /org/mooheda/gpd org.mooheda.gpd1." + method
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
            trackNotification.text += "\nSu " + station
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
                text: "🇮🇹 Global Player Italia v3.2"
                font.bold: true
                Layout.fillWidth: true
            }
            PC3.Button { 
                text: "Accedi"
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
                    text: artworkUrl.toString() === "" ? "🇮🇹" : ""
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
                    color: playState === "Playing" ? "#009246" : "transparent"
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
                            return "Nessuna informazione traccia"
                        }
                    }
                    wrapMode: Text.WordWrap
                    font.weight: Font.Medium
                }
                
                PC3.Label {
                    Layout.fillWidth: true
                    text: nowShow ? ("Programma: " + nowShow) : ""
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
                text: "Riproduci"
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
                    if (playState === "Playing") return "In riproduzione"
                    if (playState === "Paused") return "In pausa" 
                    return "Fermato"
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
                text: "Log a ~/globalplayer/gp-italy.logs"
                checked: loggingEnabled
                onToggled: qdbusCall("SetLogging", [checked ? "true" : "false"])
            }
            
            PC3.CheckBox {
                id: notifyToggle
                text: "Notifiche"
                checked: notificationsEnabled
                onToggled: notificationsEnabled = checked
            }
            
            PC3.Button { 
                text: "↻"
                onClicked: refreshStations()
                PC3.ToolTip.text: "Aggiorna elenco stazioni"
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
                        text: artworkUrl.toString() === "" ? "🇮🇹" : ""
                        opacity: 0.6
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: 4
                        height: 4
                        radius: 2
                        color: playState === "Playing" ? "#009246" : "transparent"
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
                            return "Global Player Italia"
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
                text: "Riproduci"
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
                text: notificationsEnabled ? "Disattiva Notifiche" : "Attiva Notifiche"
                onTriggered: notificationsEnabled = !notificationsEnabled
            }
            PC3.MenuItem { 
                text: loggingEnabled ? "Disattiva Logging" : "Attiva Logging"
                onTriggered: qdbusCall("SetLogging", [(!loggingEnabled).toString()]) 
            }
            PC3.MenuItem { 
                text: "Aggiorna Stazioni"
                onTriggered: refreshStations() 
            }
            PC3.MenuItem { 
                text: "Accedi"
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

echo "[+] Creating Italy station list..."
cat > "globalplayer-daemon/stations_static.json" << 'EOF'
[
  {
    "name": "RTL 102.5",
    "url": "https://streamingv2.shoutcast.com/rtl-1025"
  },
  {
    "name": "Radio Deejay",
    "url": "https://radiodeejay-lh.akamaihd.net/i/RadioDeejay_Live@189857/master.m3u8"
  },
  {
    "name": "RDS",
    "url": "https://rds.akacast.akamaistream.net/7/672/435747/v1/rm.akacast.akamaistream.net/rds"
  },
  {
    "name": "Radio 105",
    "url": "https://icy.unitedradio.it/Radio105.mp3"
  },
  {
    "name": "Virgin Radio",
    "url": "https://icy.unitedradio.it/Virgin.mp3"
  },
  {
    "name": "R101",
    "url": "https://icy.unitedradio.it/R101.mp3"
  },
  {
    "name": "Radio Kiss Kiss",
    "url": "https://ice07.fluidstream.net/KissKiss.mp3"
  },
  {
    "name": "Radio Capital",
    "url": "https://radiocapital-lh.akamaihd.net/i/RadioCapital_Live@783731/master.m3u8"
  },
  {
    "name": "Radio Rock",
    "url": "https://icy.unitedradio.it/RadioRock.mp3"
  },
  {
    "name": "Rai Radio 1",
    "url": "https://radiotoradiomainstream.akamaized.net/hls/live/2049811/RaiRadio1_AdaptiveStreaming/mp4:output_audio=64000/playlist.m3u8"
  },
  {
    "name": "Rai Radio 2",
    "url": "https://radiotoradiomainstream.akamaized.net/hls/live/2049812/RaiRadio2_AdaptiveStreaming/mp4:output_audio=64000/playlist.m3u8"
  },
  {
    "name": "Rai Radio 3",
    "url": "https://radiotoradiomainstream.akamaized.net/hls/live/2049813/RaiRadio3_AdaptiveStreaming/mp4:output_audio=64000/playlist.m3u8"
  },
  {
    "name": "Radio Italia",
    "url": "https://radioitalia-lh.akamaihd.net/i/radioitalia_1@531509/master.m3u8"
  },
  {
    "name": "Radio 24",
    "url": "https://ilsole24ore-radio.akacast.akamaistream.net/7/25/177478/v1/rm.akacast.akamaistream.net/ilsole24ore_radio"
  },
  {
    "name": "Radio Monte Carlo",
    "url": "https://icy.unitedradio.it/RMC.mp3"
  },
  {
    "name": "Subasio",
    "url": "https://subasio.shoutcast.it/autodj"
  },
  {
    "name": "Radio Zeta",
    "url": "https://radiozeta.shoutcast.it/radiozeta"
  },
  {
    "name": "M2o",
    "url": "https://icy.unitedradio.it/m2o.mp3"
  },
  {
    "name": "Radio Radicale",
    "url": "https://live.radioradicale.it/live.mp3"
  },
  {
    "name": "Isoradio",
    "url": "https://radiotoradiomainstream.akamaized.net/hls/live/2049814/RaiIsoradio_AdaptiveStreaming/mp4:output_audio=64000/playlist.m3u8"
  }
]
EOF

echo "[+] Creating Italy daemon..."
cat > "globalplayer-daemon/gpd.py" << 'EOF'
#!/usr/bin/env python3
#X-Seti (Mooheda)- Aug12 2025 - GlobalPlayer Italia - Plasma 6 Compatible
import os, json, time, re, hashlib, pathlib, threading, subprocess, tempfile
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

CONFIG_DIR = os.path.expanduser("~/.config/globalplayer-italy")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
CACHE_DIR = os.path.expanduser("~/.cache/globalplayer-italy")
ARTWORK_DIR = os.path.join(CACHE_DIR, "artwork")
LOG_DIR = os.path.expanduser("~/globalplayer")
LOG_FILE = os.path.join(LOG_DIR, "gp-italy.logs")
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
        self._log_event("SignIn requested - not needed for most Italian stations")

    def _log_event(self, text):
        ensure_dirs()
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{timestamp} | {text}\n")

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.mooheda.gpd.italy", bus)
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
        self.sock_path = socket_path or os.path.join(tempfile.gettempdir(), "gpd-italy-mpv.sock")
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
cat > "gpd-italy.service" << 'EOF'
[Unit]
Description=Global Player Italia Daemon v3.2

[Service]
Type=simple
ExecStart=/usr/bin/env python3 %h/globalplayer-daemon-italy/gpd.py
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "[+] Creating install script..."
cat > "install.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer.italy"
PLASMOID_SRC="$(dirname "$0")/${PLASMOID_ID}"
PLASMOID_DST="${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"

DAEMON_SRC="$(dirname "$0")/globalplayer-daemon"
DAEMON_DST="${HOME}/globalplayer-daemon-italy"

echo "[+] Installing Global Player Italia per Plasma 6..."
echo ""
echo "🇮🇹 Stazioni Radio Italiane:"
echo "   • Principali: RTL 102.5, Radio Deejay, RDS, Radio 105, Virgin Radio"
echo "   • Pubbliche: Rai Radio 1, Rai Radio 2, Rai Radio 3, Isoradio"
echo "   • Private: R101, Radio Kiss Kiss, Radio Capital, Radio Rock"
echo "   • Specializzate: Radio Italia, Radio 24, Radio Monte Carlo, M2o"
echo ""
echo "[+] Dipendenze necessarie:"
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
cp "$(dirname "$0")/gpd-italy.service" "${HOME}/.config/systemd/user/gpd-italy.service"
systemctl --user daemon-reload || true
systemctl --user enable --now gpd-italy.service || true

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

echo "[+] In attesa che i servizi si avviino..."
sleep 5

if systemctl --user is-active gpd-italy.service >/dev/null 2>&1; then
  echo "    ✓ Il daemon Italia è in esecuzione"
else
  echo "    ⚠ Il daemon Italia potrebbe non essere in esecuzione. Controlla: systemctl --user status gpd-italy.service"
fi

echo ""
echo "🇮🇹 Global Player Italia installato con successo!"
echo ""
echo "📱 Per aggiungere il widget:"
echo "   Clic destro sul pannello → Aggiungi Widget → Cerca 'Global Player Italia'"
EOF

echo "[+] Creating uninstall script..."
cat > "uninstall.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="org.mooheda.globalplayer.italy"

echo "[+] Disinstallazione Global Player Italia..."

systemctl --user disable --now gpd-italy.service || true
rm -f "${HOME}/.config/systemd/user/gpd-italy.service"
systemctl --user daemon-reload || true

rm -rf "${HOME}/.local/share/plasma/plasmoids/${PLASMOID_ID}"
rm -rf "${HOME}/globalplayer-daemon-italy"
rm -rf "${HOME}/.config/globalplayer-italy"
rm -rf "${HOME}/.cache/globalplayer-italy"

if systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
  systemctl --user restart plasma-plasmashell.service
else
  pkill plasmashell 2>/dev/null || true
  sleep 2
  nohup plasmashell > /dev/null 2>&1 &
fi

echo "[✓] Global Player Italia completamente rimosso."
EOF

echo "[+] Creating README..."
cat > "README.md" << 'EOF'
# 🇮🇹 Global Player Italia - Plasma 6 Widget

Un widget di KDE Plasma 6 per le stazioni radio italiane con copertine degli album e notifiche.

## 📻 Stazioni Radio Italiane

### Principali Emittenti Commerciali
- **RTL 102.5** - Radio, televisione, love songs
- **Radio Deejay** - Musica e intrattenimento
- **RDS** - 100% grandi successi
- **Radio 105** - Rock e musica alternativa
- **Virgin Radio** - Rock e pop internazionale
- **R101** - Solo grandi successi

### Emittenti Specializzate
- **Radio Kiss Kiss** - Musica italiana e internazionale
- **Radio Capital** - Rock e pop
- **Radio Rock** - Rock e metal
- **Radio Italia** - Solo musica italiana
- **Radio Monte Carlo** - Musica e informazione
- **M2o** - Musica dance ed elettronica

### Servizio Pubblico RAI
- **Rai Radio 1** - Informazione e intrattenimento
- **Rai Radio 2** - Musica e spettacolo
- **Rai Radio 3** - Cultura e musica colta
- **Isoradio** - Informazioni sul traffico

### Informazione e Tematiche
- **Radio 24** - Il Sole 24 Ore - Economia e informazione
- **Radio Radicale** - Informazione e politica
- **Subasio** - Musica e spettacolo umbro
- **Radio Zeta** - Musica per giovani

## ✨ Caratteristiche
- 🎨 **Copertine degli album** nell'icona del pannello e nelle notifiche
- 🔔 **Notifiche desktop** al cambio brano
- 🇮🇹 **Localizzazione italiana** con bandiera italiana e accenti verdi
- 🎛️ **Controllo con rotella del mouse** per cambiare stazione nel pannello
- 📝 **Registro** delle tracce riprodotte
- 🌍 **Funziona globalmente** - nessuna restrizione geografica

## 🚀 Installazione

1. **Installare le dipendenze**:
   ```bash
   # Arch Linux
   sudo pacman -S mpv qt6-tools python-dbus python-gobject python-requests
   
   # Ubuntu/Debian
   sudo apt install mpv qt6-base-dev python3-dbus python3-gi python3-requests
   
   # Fedora
   sudo dnf install mpv qt6-qtbase-devel python3-dbus python3-gobject python3-requests
   ```

2. **Installare il widget**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Aggiungere al pannello**: Clic destro sul pannello → Aggiungi Widget → "Global Player Italia"

## 🔧 Dettagli Tecnici
- **Servizio D-Bus**: `org.mooheda.gpd.italy`
- **Configurazione**: `~/.config/globalplayer-italy/`
- **Cache**: `~/.cache/globalplayer-italy/`
- **Log**: `~/globalplayer/gp-italy.logs`

## 🛠️ Risoluzione Problemi
- **Stato servizio**: `systemctl --user status gpd-italy.service`
- **Visualizza log**: `journalctl --user -u gpd-italy.service -f`
- **Riavvia Plasma**: `systemctl --user restart plasma-plasmashell.service`

## 📜 Versione
v3.2 Italia - Compatibile con Plasma 6
Creato da X-Seti (Mooheda) - Agosto 2025

## 🎵 Note
Le stazioni italiane offrono un mix perfetto di musica italiana e internazionale, 
dalle grandi emittenti commerciali al servizio pubblico RAI, con specializzazioni 
in rock, dance, informazione e cultura.
EOF

chmod +x install.sh uninstall.sh

cd ..

echo ""
echo "🇮🇹 Pacchetto Global Player Italia creato con successo!"
echo ""
echo "📁 Pacchetto: ${PACKAGE_NAME}/"
echo ""
echo "📻 Stazioni Radio Italiane:"
echo "   • Principali: RTL 102.5, Radio Deejay, RDS, Radio 105, Virgin Radio"
echo "   • Pubbliche: Rai Radio 1, Rai Radio 2, Rai Radio 3, Isoradio"
echo "   • Private: R101, Radio Kiss Kiss, Radio Capital, Radio Rock"
echo "   • Specializzate: Radio Italia, Radio 24, Radio Monte Carlo, M2o"
echo ""
echo "✨ Caratteristiche:"
echo "   • 🇮🇹 Bandiera italiana e accenti verdi"
echo "   • 🔔 Localizzazione in italiano"
echo "   • 🎨 Supporto copertine album"
echo "   • 📝 Registro in italiano"
echo ""
echo "🚀 Per installare:"
echo "   cd ${PACKAGE_NAME}"
echo "   ./install.sh"
echo ""
echo "📦 Per creare zip:"
echo "   zip -r ${PACKAGE_NAME}.zip ${PACKAGE_NAME}/"

echo ""
echo "🎵 Bonus: Next up could be France, Netherlands, or..."
echo "🚀 Mars Country Radio! 'Red Planet 105.5 - The best country hits from across the solar system!'"