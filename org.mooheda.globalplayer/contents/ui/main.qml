// X-Seti - Aug12 2025 - GlobalPlayer
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Handlers 1.5
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.plasmoid 2.0

Item {
    id: root
    width: 340
    height: 300

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

    PlasmaCore.DataSource {
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Global Player v1.0"
                font.bold: true
                Layout.fillWidth: true
            }
            PC3.Button { text: "Sign In"; onClicked: signIn() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                width: 80; height: 80; radius: 8
                border.color: "#444"; color: "#00000000"
                Image {
                    anchors.fill: parent; anchors.margins: 2
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
            ColumnLayout {
                Layout.fillWidth: true
                PC3.Label {
                    Layout.fillWidth: true
                    text: (nowArtist || nowTitle) ? (nowArtist + " — " + nowTitle) : "No track info"
                    wrapMode: Text.WordWrap
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: nowShow ? ("Show: " + nowShow) : ""
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                }
            }
        }

        ComboBox {
            id: stationPicker
            Layout.fillWidth: true
            model: stationsModel
            onActivated: {
                stationIndex = currentIndex
                playCurrent()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Button { text: "◀"; onClicked: prevStation() }
            PC3.Button { text: "Play"; onClicked: playCurrent() }
            PC3.Button { text: "Pause"; onClicked: qdbusCall("Pause", []) }
            PC3.Button { text: "▶"; onClicked: nextStation() }
            PC3.Label {
                text: playState
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                opacity: 0.7
            }
        }

        RowLayout {
            Layout.fillWidth: true
            CheckBox {
                id: logToggle
                text: "Log to ~/globalplayer/gp.logs"
                checked: loggingEnabled
                onToggled: qdbusCall("SetLogging", [checked ? "true" : "false"])
            }
            PC3.Button { text: "↻"; onClicked: refreshStations(); ToolTip.text: "Refresh station list" }
        }
    }

    // Compact panel UI
    Plasmoid.compactRepresentation: Item {
        width: PlasmaCore.Units.gridUnit * 12
        height: PlasmaCore.Units.gridUnit * 2.2

        Row {
            anchors.fill: parent
            spacing: 6

            Rectangle {
                width: parent.height; height: parent.height; radius: 6
                border.color: "#444"; color: "#00000000"
                Image { anchors.fill: parent; anchors.margins: 2; fillMode: Image.PreserveAspectFit; source: artworkUrl }
            }

            PC3.ToolButton {
                id: iconBtn
                text: stationsModel.length > 0 ? stationsModel[stationIndex] : "Global"
                onClicked: stationMenu.open()
            }
        }

        // Wheel scrolling (Qt 5/6 compatible)
        WheelHandler {
            target: this
            onWheel: {
                if (wheel.angleDelta.y > 0) prevStation(); else nextStation();
                wheel.accepted = true;
            }
        }

        Menu {
            id: stationMenu
            Repeater {
                model: stationsModel
                delegate: MenuItem {
                    text: modelData
                    checkable: true
                    checked: index === stationIndex
                    onTriggered: { stationIndex = index; playCurrent() }
                }
            }
            MenuSeparator {}
            MenuItem { text: "Play"; onTriggered: playCurrent() }
            MenuItem { text: "Pause"; onTriggered: qdbusCall("Pause", []) }
            MenuItem { text: loggingEnabled ? "Disable Logging" : "Enable Logging"; onTriggered: qdbusCall("SetLogging", [(!loggingEnabled).toString()]) }
            MenuItem { text: "Refresh Stations"; onTriggered: refreshStations() }
            MenuItem { text: "Sign In"; onTriggered: signIn() }
        }
    }
}
