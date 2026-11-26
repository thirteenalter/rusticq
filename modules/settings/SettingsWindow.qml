import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "../../components/settings" as Suite
import "../bar"
import "pages"

FloatingWindow {
    id: root
    readonly property bool presented: motion.presented
    visible: presented
    SurfaceMotion { id: motion;shown: Store.settingsVisible;target: root.contentItem;closedScale:0.995;animate:design.motionEnabled }
    screen: Store.settingsScreen
    title: "RusticQ · Settings"
    implicitWidth: Math.max(800,Math.min(SettingsStore.rusticSettingsWidth,screen?screen.width-48:1100))
    implicitHeight: Math.max(560,Math.min(SettingsStore.rusticSettingsHeight,screen?screen.height-72:760))
    minimumSize: Qt.size(800,560)
    color: "transparent"
    SettingsDesignTokens { id: design;application:"rusticq" }
    property string query: ""
    property string highlightedSection: ""
    property var history: []
    property int historyIndex: 0
    function groupFor(key) {
        if(["wifi","bluetooth","audio"].indexOf(key)>=0)return "Connectivity";
        if(["power","display","os","hardware","apps","storage","updates"].indexOf(key)>=0)return "System";
        if(["glass","typography","motion","lockscreen","notes","window-appearance"].indexOf(key)>=0)return "Personalization";
        if(["compositor","shortcuts","ai","integration"].indexOf(key)>=0)return "Integration";
        return key==="about"?"General":"Desktop";
    }
    readonly property var pages: [
        {key:"home", label:"Settings", symbol:"\ue8b8", detail:"All desktop and system settings"},
        {key:"ui", label:"UI settings", symbol:"\ue40a", detail:"Personalize the RusticQ interface"},
        {key:"system", label:"System settings", symbol:"\ue8b8", detail:"Connections, devices and Linux"},
        {key:"wifi", label:"Wi-Fi", symbol:"\ue63e", detail:"Networks, hidden Wi-Fi, QR and DNS"},
        {key:"bluetooth", label:"Bluetooth", symbol:"\ue1a7", detail:"Pair and connect wireless devices"},
        {key:"audio", label:"Audio", symbol:"\ue050", detail:"Speakers, microphones and application mixer"},
        {key:"power", label:"Battery & power", symbol:"\uf304", detail:"Battery status and power profiles"},
        {key:"clock", label:"Clock", symbol:"\ue8b5", detail:"Alarms, timer sounds and clock format"},
        {key:"appearance", label:"Appearance", symbol:"\ue40a", detail:"Themes & palette"},
        {key:"bar", label:"Bar & Dock", symbol:"\ue30b", detail:"Layout & margins"},
        {key:"modules", label:"Modules", symbol:"\ue429", detail:"Indicators & menus"},
        {key:"widgets", label:"Widgets", symbol:"\ue916", detail:"Desktop cards"},
        {key:"notes", label:"Notes & Kanban", symbol:"\ue873", detail:"Local personal task board"},
        {key:"dock", label:"Dock", symbol:"\ue8b8", detail:"Apps & auto-hide"},
        {key:"launcher", label:"App Launcher", symbol:"\ue8b6", detail:"Window & icon size"},
        {key:"display", label:"Displays", symbol:"\ue30b", detail:"Monitor arrangement"},
        {key:"compositor", label:Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")?"Hyprland Settings":"Compositor", symbol:"\ue8b8", detail:"Hyprland / Niri graphical config"},
        {key:"os", label:"OS information", symbol:"\ue88e", detail:"Linux & session"},
        {key:"hardware", label:"Hardware", symbol:"\ue322", detail:"CPU, GPU & RAM"},
        {key:"apps", label:"Installed apps", symbol:"\ue5c3", detail:"Package inventory"},
        {key:"storage", label:"Storage", symbol:"\ue1db", detail:"Disks & maintenance"},
        {key:"updates", label:"Arch Updater", symbol:"\ue5d5", detail:"Packages & terminal"},
        {key:"shortcuts", label:"Shortcuts", symbol:"\ue312", detail:"Edit and restore keybindings"},
        {key:"integration", label:"Integration", symbol:"\ue8b8", detail:"Dependencies & permanent shell"},
        {key:"ai", label:"AI Providers", symbol:"\uf371", detail:"Cloud assistant"},
        {key:"about", label:"About", symbol:"\ue88e", detail:"Version and release history"},

        {key:"quickcontrol",label:"Quick Control",symbol:"\ue429",detail:"Independent modules and advanced controls"},
        {key:"glass",label:"Glassmorphism & RAGE",symbol:"\ue53b",detail:"Global and settings materials"},
        {key:"window-appearance",label:"Settings Window Appearance",shortLabel:"Settings Appearance",symbol:"\ue40a",detail:"Shared settings suite materials and per-app overrides"},
        {key:"typography",label:"Typography",symbol:"\ue264",detail:"Font family and interface density"},
        {key:"motion",label:"Motion & Animations",symbol:"\ue1c4",detail:"Interface motion preferences"},
        {key:"wallpaper",label:"Wallpaper & Themes",symbol:"\ue3f4",detail:"Wallpaper engines and theme preferences"},
        {key:"lockscreen",label:"Lock Screen",symbol:"\ue897",detail:"Native lock screen appearance"},
        {key:"notifications",label:"Notifications",symbol:"\ue7f4",detail:"Notification history and Do Not Disturb"},
    ]
    readonly property var searchItems: [
        {tab:"appearance", title:"Surface Spacing", hint:"padding panel popup card control search field content gap density manual pixels"},
        {tab:"appearance", title:"Network Panel", hint:"speed test speedometer gauge ping download upload Ookla classic modern arc compact animation glow last test time"},
        {tab:"appearance", title:"Quick Control", hint:"classic modular frameless control center panel component icon background outline glass accent opacity radius spacing width compact animations"},
        {tab:"home", title:"Full settings", hint:"All UI and system settings home overview"},
        {tab:"ui", title:"UI settings", hint:"Personalize RusticQ appearance bar dock widgets"},
        {tab:"system", title:"System settings", hint:"Wi-Fi Bluetooth audio battery displays Linux devices"},
        {tab:"wifi", title:"Wi-Fi settings", hint:"Wireless networks scan connect disconnect forget hidden SSID password DNS QR"},
        {tab:"bluetooth", title:"Bluetooth settings", hint:"Wireless devices scan pair connect disconnect BlueZ adapter"},
        {tab:"audio", title:"Audio settings and application mixer", hint:"Speaker microphone audio bus per-app volume mute live level meter PipeWire"},
        {tab:"power", title:"Battery and power", hint:"Charge energy power profiles performance balanced saver"},
        {tab:"clock", title:"Clock, alarms and timer sound", hint:"Alarm daily repeat snooze loop sound audio file volume 125 percent calendar format"},
        {tab:"appearance", title:"Color theme and accent", hint:"Aether Gruvbox theme palette"},
        {tab:"appearance", title:"Wallpaper settings", hint:"Wallpaper swww awww hyprpaper image path"},
        {tab:"appearance", title:"RusticQ Lock Screen", hint:"Hyprlock PAM password clock secure wallpaper lock screen"},
        {tab:"appearance", title:"Typography and density", hint:"Font family size text compact comfortable"},
        {tab:"appearance", title:"Interface animations", hint:"Motion smooth fade slide popup panel on off"},
        {tab:"appearance", title:"RAGE Glassmorphism", hint:"Rustiq adaptive glass engine frosted crystal tinted transparency opacity blur border reflection shadow performance"},
        {tab:"bar", title:"Bar position", hint:"Top Bottom Left Right"},
        {tab:"bar", title:"Bar animation style", hint:"Float Fade Slide Zoom Spring motion preview"},
        {tab:"bar", title:"Bar icon size in pixels", hint:"Icon symbol size 12 32 px slider exact input"},
        {tab:"bar", title:"Absolute center positioning", hint:"Centered icons screen middle offset"},
        {tab:"bar", title:"Bar layout and Clean Compact", hint:"Professional Compact Separated Simple Hover"},
        {tab:"bar", title:"Realtime margin editor", hint:"Spacing Edge Margin Slider"},
        {tab:"bar", title:"Icon spacing: Left, Center and Right", hint:"Per-icon spacing follows icon alignment; microphone wifi battery download upload all modes"},
        {tab:"bar", title:"Extra status icons", hint:"Microphone network download upload left center right"},
        {tab:"bar", title:"Bar icon alignment", hint:"Relocate every icon left center right clock wifi battery audio task quick control menu"},
        {tab:"modules", title:"Independent icon profiles per layout", hint:"Simple Compact Clean Compact Separated Professional icon visibility per mode presets minimal"},
        {tab:"modules", title:"App launcher and status modules", hint:"Icons Wifi Bluetooth Battery Audio Weather Clock"},
        {tab:"modules", title:"Menu bar and quick modes", hint:"Edit View Share File Shell Tools Night Silent"},
        {tab:"modules", title:"Recording indicator", hint:"Screen recording red dot blink position corner size margin inset"},
        {tab:"widgets", title:"Desktop widgets", hint:"Calendar Clock CPU RAM Music Media Now Playing Weather Connectivity Battery"},
        {tab:"notes", title:"Notes and Kanban", hint:"todo list writing memo private local tasks columns doing done"},
        {tab:"dock", title:"Custom dock", hint:"Apps Auto-hide Files Browser"},
        {tab:"launcher", title:"App launcher dimensions", hint:"Window width height icon size favorites columns row height"},
        {tab:"display", title:"Monitor configuration", hint:"Resolution Refresh rate Scale Position"},
        {tab:"compositor", title:"Compositor studio", hint:"Hyprland Niri autostart gaps rounding input keyboard touchpad monitors graphical configuration preview backup rollback"},
        {tab:"os", title:"Operating system information", hint:"Linux kernel distro hostname uptime session"},
        {tab:"hardware", title:"Hardware details", hint:"CPU GPU PCI motherboard RAM BIOS sensors"},
        {tab:"apps", title:"Installed applications", hint:"Pacman package list foreign explicit AUR install uninstall graphical application remove risk warning"},
        {tab:"storage", title:"Storage maintenance", hint:"Disk capacity filesystem mount cache journal"},
        {tab:"updates", title:"Arch Updater", hint:"Check updates upgrade downloads pacman progress logs terminal"},
        {tab:"shortcuts", title:"Keybindings", hint:"Hyprland shortcut keys override Lua Omarchy default bindings Settings Launcher Quick AI"},
        {tab:"integration", title:"Required and optional dependencies", hint:"Packages install python quickshell Material Symbols WiFi Bluetooth screen recording screenshot arch"},
        {tab:"integration", title:"Make RusticQ Permanent", hint:"Omarchy shell replacement backup enable revert startup persistent"},
        {tab:"ai", title:"AI provider setup", hint:"OpenAI Anthropic Claude Gemini API key"},
        {tab:"about", title:"About RusticQ", hint:"Version release history changelog beta alpha Quickshell"}
    ]

    readonly property var systemPages: ["system","wifi","bluetooth","audio","power","clock","display","compositor","os","hardware","apps","storage","updates","shortcuts"]
    readonly property var activePage: pages.find(p=>p.key===Store.settingsTab) || pages[0]
    readonly property string settingsGroup: Store.settingsTab==="system"?"system":Store.settingsTab==="ui"?"ui":"home"
    readonly property var navigationPages: pages.filter(p=>["home","ui","system","dock"].indexOf(p.key)<0).map(p=>Object.assign({},p,{group:groupFor(p.key)})).sort((a,b)=>{const groups=["Desktop","Connectivity","System","Personalization","Integration","General"];const order=["appearance","wallpaper","bar","quickcontrol","launcher","modules","widgets","notifications","clock","wifi","bluetooth","audio","power","display","hardware","storage","apps","updates","os","glass","window-appearance","typography","motion","lockscreen","notes","compositor","shortcuts","ai","integration","about"];return (groups.indexOf(a.group)-groups.indexOf(b.group))*100+order.indexOf(a.key)-order.indexOf(b.key);})
    readonly property var matched: searchItems.concat(navigationPages.map(p=>({tab:p.key,title:p.label,hint:p.detail,icon:p.symbol}))).filter(item=>(item.title+" "+item.hint+" "+item.tab).toLowerCase().includes(query.trim().toLowerCase()))
    function navigate(tab,option) {
        if(tab==="compositor" && !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) { Store.openHyprSettings("overview",root.screen);return; }
        Store.settingsTab=pages.some(p=>p.key===tab)?tab:"home";
        query="";frame.query="";frame.contentY=0;highlightedSection=option || "";highlightTimer.restart();
    }
    function travel(delta) {
        const next=historyIndex+delta;if(next<0 || next>=history.length)return;
        historyIndex=next;navigate(history[next],"");
    }
    function saveGeometry() {
        if(!maximized && !minimized) {SettingsStore.rusticSettingsWidth=Math.round(width);SettingsStore.rusticSettingsHeight=Math.round(height);SettingsStore.save();}
    }
    onClosed: {saveGeometry();Store.settingsVisible=false;}
    Connections { target:Store;function onSettingsTabChanged() {
        if(root.history[root.historyIndex]===Store.settingsTab)return;
        root.history=root.history.slice(0,root.historyIndex+1).concat([Store.settingsTab]);root.historyIndex=root.history.length-1;
    } }
    Timer { id:highlightTimer;interval:2400;onTriggered:root.highlightedSection="" }
    Timer { id:floatingCheckTimer;interval:320;onTriggered:if(root.visible && !floatHelper.running)floatHelper.running=true }
    Process { id:floatHelper;command:["python3",Quickshell.shellPath("scripts/rustiq-settings-float.py")] }
    Component.onCompleted: {history=[Store.settingsTab];floatingCheckTimer.restart();}
    Shortcut {sequence:"Ctrl+F";onActivated:frame.focusSearch()}
    Shortcut {sequence:"Ctrl+K";onActivated:frame.focusSearch()}
    Shortcut {sequence:"Alt+Left";onActivated:root.travel(-1)}
    Shortcut {sequence:"Alt+Right";onActivated:root.travel(1)}
    Suite.SettingsWindowFrame {
        id:frame;anchors.fill:parent;window:root;design:design
        applicationTitle:"RusticQ Settings";applicationIcon:Quickshell.shellPath("assets/rusticq-app-icon.svg");version:ReleaseInfo.displayName
        title:root.activePage.label;description:root.activePage.detail;symbol:root.activePage.symbol
        page:Store.settingsTab==="dock"?"bar":Store.settingsTab;categories:root.navigationPages;results:root.matched;highlight:root.highlightedSection
        query:root.query;onQueryChanged:if(query!==root.query)root.query=query
        canBack:root.historyIndex>0;canForward:root.historyIndex<root.history.length-1
        onBack:root.travel(-1);onForward:root.travel(1);onNavigate:(tab,option)=>root.navigate(tab,option)
        status: design.glassEnabled && !design.verifiedBlur ? design.capabilityText : "Interface changes save automatically"
        toolbar: Component { DeviceSettingsButton {
            objectName:"openFloatingDeviceSettings"
            visible:["wifi","bluetooth","audio","power"].indexOf(root.activePage.key)>=0
            kind:root.activePage.key;section:kind==="wifi"?"details":kind==="audio"?"applications":"";iconOnly:true;targetScreen:root.screen
        } }
        Loader {
            id:pageLoader;Layout.fillWidth:true
            onLoaded: pageMotion.replay()
            SurfaceMotion {id:pageMotion;shown:Store.settingsVisible;target:pageLoader.item;closedScale:1}
            sourceComponent: Store.settingsTab === "quickcontrol" ? quickControlPage :
                            Store.settingsTab === "glass" ? glassPage :
                            Store.settingsTab === "window-appearance" ? windowAppearancePage :
                            Store.settingsTab === "notifications" ? notificationsPage :
                            ["typography","motion","wallpaper","lockscreen"].indexOf(Store.settingsTab)>=0 ? appearancePage : Store.settingsTab === "home" || Store.settingsTab === "ui" || Store.settingsTab === "system" ? homePage :
                            Store.settingsTab === "wifi" ? wifiPage :
                            Store.settingsTab === "bluetooth" ? bluetoothPage :
                            Store.settingsTab === "audio" ? audioPage :
                            Store.settingsTab === "power" ? powerPage :
                            Store.settingsTab === "clock" ? clockPage :
                            Store.settingsTab === "appearance" ? appearancePage :
                            Store.settingsTab === "bar" ? barPage :
                            Store.settingsTab === "modules" ? modulesPage :
                            Store.settingsTab === "widgets" ? widgetsPage :
                            Store.settingsTab === "notes" ? notesPage :
                            Store.settingsTab === "dock" ? dockPage :
                            Store.settingsTab === "launcher" ? launcherPage :
                            Store.settingsTab === "display" ? displayPage :
                            Store.settingsTab === "compositor" ? compositorPage :
                            Store.settingsTab === "os" ? osPage :
                            Store.settingsTab === "hardware" ? hardwarePage :
                            Store.settingsTab === "apps" ? appsPage :
                            Store.settingsTab === "storage" ? storagePage :
                            Store.settingsTab === "updates" ? updatesPage :
                            Store.settingsTab === "shortcuts" ? shortcutsPage :
                            Store.settingsTab === "integration" ? integrationPage :
                            Store.settingsTab === "ai" ? aiPage :
                            Store.settingsTab === "about" ? aboutPage : homePage
        }
    }
    Component { id: homePage; SettingsHomePage {
        group: root.settingsGroup
        catalog: root.pages
        systemPages: root.systemPages
        onNavigateRequested: tab => root.navigate(tab)
    } }
    Component { id: wifiPage; SettingsWifiPage {} }
    Component { id: bluetoothPage; SettingsBluetoothPage {} }
    Component { id: audioPage; SettingsAudioPage {} }
    Component { id: powerPage; SettingsPowerPage {} }
    Component { id: clockPage; SettingsClockPage {} }
    Component { id: quickControlPage; QuickControlSettings {} }
    Component { id: glassPage; ColumnLayout { GlassSettings {Layout.fillWidth:true} SettingsSurfaceMaterials {Layout.fillWidth:true} } }
    Component { id: windowAppearancePage; SettingsWindowAppearance {} }
    Component { id: notificationsPage; BarNotifications { standalone:true; expanded:true } }
    Component { id: appearancePage; SettingsAppearancePage { sectionFilter:["typography","motion","wallpaper","lockscreen"].indexOf(Store.settingsTab)>=0?Store.settingsTab:"" } }
    Component { id: barPage; SettingsBarPage {} }
    Component { id: modulesPage; SettingsModulesPage {} }
    Component { id: widgetsPage; SettingsWidgetsPage {} }
    Component { id: notesPage; SettingsNotesPage {} }
    Component { id: dockPage; SettingsDockPage {} }
    Component { id: launcherPage; SettingsLauncherPage {} }
    Component { id: displayPage; SettingsDisplaysPage {} }
    Component { id: compositorPage; SettingsCompositorPage {} }
    Component { id: osPage; SettingsOSPage {} }
    Component { id: hardwarePage; SettingsHardwarePage {} }
    Component { id: appsPage; SettingsAppsPage {} }
    Component { id: storagePage; SettingsStoragePage {} }
    Component { id: updatesPage; SettingsUpdaterPage {} }
    Component { id: shortcutsPage; SettingsShortcutsPage {} }
    Component { id: integrationPage; SettingsIntegrationPage {} }
    Component { id: aiPage; SettingsAIPage {} }
    Component { id: aboutPage; SettingsAboutPage {} }
}
