#!/usr/bin/env bash
# Global Player Regional Package Selector - Complete Edition
# Master script to create different regional packages

set -euo pipefail

echo "🎵 Global Player Regional Package Creator"
echo "========================================"
echo ""
echo "Which version would you like to create?"
echo ""
echo "🌍 English-Speaking:"
echo "1) 🇬🇧 UK Version (Heart, Capital, Classic FM, LBC, etc.)"
echo "2) 🇺🇸 USA Version (iHeartRadio, NPR, KEXP, Soma FM, etc.)"  
echo "3) 🇨🇦 Canada Version (Jack FM, Virgin Radio, CBC, etc.)"
echo ""
echo "🌍 European:"
echo "4) 🇩🇪 Germany Version (1LIVE, Bayern 3, SWR3, Deutschlandfunk, etc.)"
echo "5) 🇪🇸 Spain Version (Cadena SER, Los 40, Europa FM, etc.)"
echo "6) 🇮🇹 Italy Version (RTL 102.5, Radio Deejay, RDS, Rai Radio, etc.)"
echo ""
echo "🌍 Multi-Regional:"
echo "7) 🌍 All Versions (creates all available packages)"
echo "8) ℹ️  Show detailed package information"
echo "9) 🚀 Mars Country Radio (Coming Soon to a planet near you!)"
echo ""
read -p "Enter choice (1-8): " choice

case $choice in
    1) 
        echo "[+] Creating UK package..."
        if [[ -f "./create_uk_package.sh" ]]; then
            ./create_uk_package.sh
        else
            echo "❌ create_uk_package.sh not found!"
            echo "💡 You need to create the UK generator script first."
            exit 1
        fi
        ;;
    2) 
        echo "[+] Creating USA package..."
        if [[ -f "./create_usa_package.sh" ]]; then
            ./create_usa_package.sh
        else
            echo "❌ create_usa_package.sh not found!"
            echo "💡 You need to create the USA generator script first."
            exit 1
        fi
        ;;
    3) 
        echo "[+] Creating Canada package..."
        if [[ -f "./create_canada_package.sh" ]]; then
            ./create_canada_package.sh
        else
            echo "❌ create_canada_package.sh not found!"
            echo "💡 You need to create the Canada generator script first."
            exit 1
        fi
        ;;
    #!/usr/bin/env bash
# Global Player Regional Package Selector
# Master script to create different regional packages

set -euo pipefail

echo "🎵 Global Player Regional Package Creator"
echo "========================================"
echo ""
echo "Which version would you like to create?"
echo ""
echo "1) 🇬🇧 UK Version (Heart, Capital, Classic FM, LBC, etc.)"
echo "2) 🇺🇸 USA Version (iHeartRadio, NPR, KEXP, Soma FM, etc.)"  
echo "3) 🇨🇦 Canada Version (Jack FM, Virgin Radio, CBC, etc.)"
echo "4) 🌍 All Versions (creates all three packages)"
echo "5) ℹ️  Show package details"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1) 
        echo "[+] Creating UK package..."
        if [[ -f "./create_uk_package.sh" ]]; then
            ./create_uk_package.sh
        else
            echo "❌ create_uk_package.sh not found!"
            echo "💡 You need to create the UK generator script first."
            exit 1
        fi
        ;;
    2) 
        echo "[+] Creating USA package..."
        if [[ -f "./create_usa_package.sh" ]]; then
            ./create_usa_package.sh
        else
            echo "❌ create_usa_package.sh not found!"
            echo "💡 You need to create the USA generator script first."
            exit 1
        fi
        ;;
    4) 
        echo "[+] Creating Germany package..."
        if [[ -f "./create_germany_package.sh" ]]; then
            ./create_germany_package.sh
        else
            echo "❌ create_germany_package.sh not found!"
            echo "💡 You need to create the Germany generator script first."
            exit 1
        fi
        ;;
    5) 
        echo "[+] Creating Spain package..."
        if [[ -f "./create_spain_package.sh" ]]; then
            ./create_spain_package.sh
        else
            echo "❌ create_spain_package.sh not found!"
            echo "💡 You need to create the Spain generator script first."
            exit 1
        fi
        ;;
    6) 
        echo "[+] Italy package coming soon..."
        echo "🚧 Italy package generator is under development."
        echo "📧 Check back for updates or contribute Italian radio stations!"
        ;;
    7) 
        echo "[+] Creating all available packages..."
        echo ""
        
        if [[ -f "./create_uk_package.sh" ]]; then
            echo "🇬🇧 Creating UK package..."
            ./create_uk_package.sh
            echo ""
        else
            echo "⚠️  create_uk_package.sh not found, skipping UK package"
        fi
        
        if [[ -f "./create_usa_package.sh" ]]; then
            echo "🇺🇸 Creating USA package..."
            ./create_usa_package.sh
            echo ""
        else
            echo "⚠️  create_usa_package.sh not found, skipping USA package"
        fi
        
        if [[ -f "./create_canada_package.sh" ]]; then
            echo "🇨🇦 Creating Canada package..."
            ./create_canada_package.sh
            echo ""
        else
            echo "⚠️  create_canada_package.sh not found, skipping Canada package"
        fi
        
        if [[ -f "./create_germany_package.sh" ]]; then
            echo "🇩🇪 Creating Germany package..."
            ./create_germany_package.sh
            echo ""
        else
            echo "⚠️  create_germany_package.sh not found, skipping Germany package"
        fi
        
        if [[ -f "./create_italy_package.sh" ]]; then
            echo "🇮🇹 Creating Italy package..."
            ./create_italy_package.sh
            echo ""
        else
            echo "⚠️  create_italy_package.sh not found, skipping Italy package"
        fi
        
        echo "✅ All available packages created!"
        echo ""
        echo "📦 To create zip files for distribution:"
        echo "   zip -r Global-Player-UK.zip Global-Player-UK/"
        echo "   zip -r Global-Player-USA.zip Global-Player-USA/"
        echo "   zip -r Global-Player-Canada.zip Global-Player-Canada/"
        echo "   zip -r Global-Player-Germany.zip Global-Player-Germany/"
        echo "   zip -r Global-Player-Spain.zip Global-Player-Spain/"
        echo "   zip -r Global-Player-Italy.zip Global-Player-Italy/"
        ;;
    8)
        echo ""
        echo "📋 Detailed Package Information:"
        echo ""
        echo "🇬🇧 UK Package (Premium Features):"
        echo "   • Heart Network: UK, London, 60s, 70s, 80s, 90s, 00s, Dance, Xmas"
        echo "   • Capital Network: UK, London, Dance, XTRA, XTRA Reloaded"
        echo "   • Classic FM & Classic FM Relax"
        echo "   • LBC & LBC News (Talk radio)"
        echo "   • Smooth: UK, London, Chill, Country"
        echo "   • Radio X & Radio X Classic Rock"
        echo "   • Gold (Greatest hits)"
        echo "   • 🔐 Sign-in support for premium Global Player features"
        echo "   • 🕸️ Web scraping discovers additional stations"
        echo "   • 🔑 KWallet cookie storage"
        echo ""
        echo "🇺🇸 USA Package:"
        echo "   • NPR News (National Public Radio)"
        echo "   • iHeartRadio: KOST 103.5, KROQ 106.7, KIIS FM, Z100, Power 106"
        echo "   • Independent: Radio Paradise, KEXP Seattle, Soma FM"
        echo "   • Public radio: WXPN, WFUV, KCRW"
        echo "   • 🔓 No geo-restrictions for USA listeners"
        echo "   • 🎵 No sign-in required"
        echo ""
        echo "🇨🇦 Canada Package:"
        echo "   • Jack FM: Vancouver 96.9, Calgary 103.1"
        echo "   • Toronto: Virgin Radio 99.9, Kiss 92.5, 102.1 The Edge, Q107"
        echo "   • CBC: Radio One (news/talk), CBC Music"
        echo "   • Regional: CFOX Vancouver, CHOM Montreal, Rock 95 Barrie"
        echo "   • 🍁 Canadian content and regional focus"
        echo ""
        echo "🇩🇪 Germany Package (Deutsche Lokalisierung):"
        echo "   • Öffentlich-rechtlich: 1LIVE, WDR 2, Bayern 3, SWR3, NDR 2, HR3"
        echo "   • Jugendwellen: MDR Jump, Radio Fritz, Deutschlandfunk Nova"
        echo "   • Private: Antenne Bayern, Radio Hamburg, BigFM, Energy Berlin"
        echo "   • Spezial: Deutschlandfunk, Klassik Radio, Radio Bob, Rock Antenne"
        echo "   • 🇩🇪 Deutsche Sprache und Lokalisierung"
        echo "   • 🟡 Gold-Akzente (deutsche Flaggenfarben)"
        echo ""
        echo "🇮🇹 Italy Package (Localizzazione Italiana):"
        echo "   • Principali: RTL 102.5, Radio Deejay, RDS, Radio 105, Virgin Radio"
        echo "   • Pubbliche: Rai Radio 1, Rai Radio 2, Rai Radio 3, Isoradio"
        echo "   • Private: R101, Radio Kiss Kiss, Radio Capital, Radio Rock"
        echo "   • Specializzate: Radio Italia, Radio 24, Radio Monte Carlo, M2o"
        echo "   • 🇮🇹 Lingua italiana e localizzazione"
        echo "   • 🟢 Accenti verdi (colori della bandiera italiana)"
        echo ""
        echo "🔧 Technical Features (All Packages):"
        echo "   • 🎨 Album artwork in panel icon and notifications"
        echo "   • 🔔 Desktop notifications when songs change"
        echo "   • 🎛️ Mouse wheel station switching in panel"
        echo "   • 📝 Logging of played tracks"
        echo "   • 🔄 Separate D-Bus services (no conflicts between regions)"
        echo "   • 🏠 Separate config directories"
        echo "   • 🌐 Can install multiple regions simultaneously"
        echo "   • ⚡ Plasma 6 compatible"
        echo ""
        echo "🚀 Installation Requirements:"
        echo "   • KDE Plasma 6"
        echo "   • mpv (media player)"
        echo "   • Qt6 tools"
        echo "   • Python 3 with D-Bus, GObject, requests"
        echo "   • Optional: PyQt6 WebEngine (for UK sign-in)"
        echo ""
        ;;
    9)
        echo ""
        echo "🚀 Mars Country Radio - Coming Soon!"
        echo "======================================="
        echo ""
        echo "📡 Broadcasting from the Red Planet:"
        echo "   • 🎵 'Life on Mars 105.5' - Classic rock from another world"
        echo "   • 🤠 'Red Planet Country' - Cosmic country hits"
        echo "   • 🛸 'Space Station Alpha' - Interplanetary news and weather"
        echo "   • 🌌 'Galaxy FM' - The universe's favorite music mix"
        echo ""
        echo "🎧 Now Playing: David Bowie - Space Oddity"
        echo "📊 Solar radiation levels: Moderate"
        echo "🌡️  Mars weather: -80°C with a chance of dust storms"
        echo ""
        echo "💫 Features:"
        echo "   • 🛸 Zero-gravity-optimized interface"
        echo "   • 🌟 Asteroid-belt traffic reports"
        echo "   • 🚀 SpaceX launch notifications"
        echo "   • 👽 Alien language subtitle support"
        echo ""
        echo "🔜 Coming to Earth in update v4.0!"
        echo "    (Requires: 3D TV, space suit, and interplanetary internet)"
        ;;
    *) 
        echo "❌ Invalid choice: $choice"
        echo "💡 Please enter 1-9"
        exit 1 
        ;;
esac

echo ""
echo "✨ Done! Check the created package directories."
echo ""
echo "🎯 Quick Start:"
echo "   cd [Package-Directory]"
echo "   ./install.sh"
echo "   Right-click panel → Add Widgets → Search for your regional player"