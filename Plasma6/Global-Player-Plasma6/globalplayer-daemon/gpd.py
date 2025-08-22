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
