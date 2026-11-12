import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "pages"

// Floating settings: the compositor owns window rounding and decorations.
// Internal cards retain the RusticQ design system, while the outer canvas is square.
FloatingWindow {
    id: root
    visible: Store.settingsVisible
    screen: Store.settingsScreen
    title: "RusticQ · Settings"
    // v5: roomy 1100 × 760 settings window, clamped to active monitor bounds.
    implicitWidth: Math.max(600, Math.min(1100, screen ? screen.width - 64 : 1100))
    implicitHeight: Math.max(480, Math.min(760, screen ? screen.height - 88 : 760))
    minimumSize: Qt.size(600, 480)
    maximized: false
    fullscreen: false
    color: Theme.background
    property string query: ""
    readonly property var pages: [
        {key:"home", label:"Settings", symbol:"\ue8b8", detail:"All desktop and system settings"},
        {key:"ui", label:"UI settings", symbol:"\ue40a", detail:"Personalize the RusticQ interface"},
        {key:"system", label:"System settings", symbol:"\ue8b8", detail:"Connections, devices and Linux"},
        {key:"wifi", label:"Wi-Fi", symbol:"\ue63e", detail:"Networks, hidden Wi-Fi, QR and DNS"},
        {key:"bluetooth", label:"Bluetooth", symbol:"\ue1a7", detail:"Pair and connect wireless devices"},
        {key:"audio", label:"Audio", symbol:"\ue050", detail:"Speakers, microphones and application mixer"},
        {key:"power", label:"Battery & power", symbol:"\uf304", detail:"Battery status and power profiles"},
        {key:"appearance", label:"Appearance", symbol:"\ue40a", detail:"Themes & palette"},
        {key:"bar", label:"Bar", symbol:"\ue30b", detail:"Layout & margins"},
        {key:"modules", label:"Modules", symbol:"\ue429", detail:"Indicators & menus"},
        {key:"widgets", label:"Widgets", symbol:"\ue916", detail:"Desktop cards"},
        {key:"notes", label:"Notes & Kanban", symbol:"\ue873", detail:"Local personal task board"},
        {key:"dock", label:"Dock", symbol:"\ue8b8", detail:"Apps & auto-hide"},
        {key:"launcher", label:"App Launcher", symbol:"\ue8b6", detail:"Window & icon size"},
        {key:"display", label:"Displays", symbol:"\ue30b", detail:"Monitor arrangement"},
        {key:"compositor", label:"Compositor", symbol:"\ue8b8", detail:"Hyprland / Niri graphical config"},
        {key:"os", label:"OS information", symbol:"\ue88e", detail:"Linux & session"},
        {key:"hardware", label:"Hardware", symbol:"\ue322", detail:"CPU, GPU & RAM"},
        {key:"apps", label:"Installed apps", symbol:"\ue5c3", detail:"Package inventory"},
        {key:"storage", label:"Storage", symbol:"\ue1db", detail:"Disks & maintenance"},
        {key:"updates", label:"Arch Updater", symbol:"\ue5d5", detail:"Packages & terminal"},
        {key:"shortcuts", label:"Shortcuts", symbol:"\ue312", detail:"Edit and restore keybindings"},
        {key:"integration", label:"Integration", symbol:"\ue8b8", detail:"Dependencies & permanent shell"},
        {key:"ai", label:"AI Providers", symbol:"\uf371", detail:"Cloud assistant"},
        {key:"about", label:"About", symbol:"\ue88e", detail:"Version and release history"}
    ]
    readonly property var systemPages: ["system", "wifi", "bluetooth", "audio", "power", "display", "compositor", "os", "hardware", "apps", "storage", "updates", "shortcuts"]
    readonly property var activePage: pages.find(p => p.key === Store.settingsTab) || pages[0]
    readonly property string settingsGroup: activePage.key === "home" ? "home"
        : systemPages.indexOf(activePage.key) >= 0 ? "system" : "ui"
    readonly property var navigationPages: pages.filter(page => ["home", "ui", "system"].indexOf(page.key) < 0
        && (settingsGroup === "home" || (systemPages.indexOf(page.key) >= 0 ? "system" : "ui") === settingsGroup))
    readonly property var searchItems: [
        {tab:"home", title:"Full settings", hint:"All UI and system settings home overview"},
        {tab:"ui", title:"UI settings", hint:"Personalize RusticQ appearance bar dock widgets"},
        {tab:"system", title:"System settings", hint:"Wi-Fi Bluetooth audio battery displays Linux devices"},
        {tab:"wifi", title:"Wi-Fi settings", hint:"Wireless networks scan connect disconnect forget hidden SSID password DNS QR"},
        {tab:"bluetooth", title:"Bluetooth settings", hint:"Wireless devices scan pair connect disconnect BlueZ adapter"},
        {tab:"audio", title:"Audio settings and application mixer", hint:"Speaker microphone audio bus per-app volume mute live level meter PipeWire"},
        {tab:"power", title:"Battery and power", hint:"Charge energy power profiles performance balanced saver"},
        {tab:"appearance", title:"Color theme and accent", hint:"Aether Gruvbox theme palette"},
        {tab:"appearance", title:"Wallpaper settings", hint:"Wallpaper swww awww hyprpaper image path"},
        {tab:"appearance", title:"RusticQ Lock Screen", hint:"Hyprlock PAM password clock secure wallpaper lock screen"},
        {tab:"appearance", title:"Typography and density", hint:"Font family size text compact comfortable"},
        {tab:"bar", title:"Bar position", hint:"Top Bottom Left Right"},
        {tab:"bar", title:"Absolute center positioning", hint:"Centered icons screen middle offset"},
        {tab:"bar", title:"Bar layout and Clean Compact", hint:"Professional Compact Separated Simple Hover"},
        {tab:"bar", title:"Realtime margin editor", hint:"Spacing Edge Margin Slider"},
        {tab:"bar", title:"Icon spacing: Left, Center and Right", hint:"Per-icon spacing follows icon alignment; microphone wifi battery download upload all modes"},
        {tab:"bar", title:"Extra status icons", hint:"Microphone network download upload left center right"},
        {tab:"bar", title:"Bar icon alignment", hint:"Relocate every icon left center right clock wifi battery audio task quick control menu"},
        {tab:"modules", title:"Independent icon profiles per layout", hint:"Simple Compact Clean Compact Separated Professional icon visibility per mode presets minimal"},
        {tab:"modules", title:"App launcher and status modules", hint:"Icons Wifi Bluetooth Battery Audio Weather Clock"},
        {tab:"modules", title:"Menu bar and quick modes", hint:"Edit View Share File Shell Tools Night Silent"},
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
    readonly property var matched: searchItems.filter(item => (item.title + " " + item.hint + " " + item.tab).toLowerCase().indexOf(query.toLowerCase().trim()) !== -1)
    function navigate(tab) {
        Store.settingsTab = pages.some(page => page.key === tab) ? tab : "home";
        root.query = "";
        searchField.text = "";
        contentView.contentY = 0;
    }
    onVisibleChanged: {
        if (visible) floatingCheckTimer.restart()
        else Store.settingsVisible = false
    }
    Component.onCompleted: if (visible) floatingCheckTimer.restart()

    // Hyprland normally tiles regular toplevels, even FloatingWindow.
    // Resolve this window by exact title and float only that window, once on open.
    // Never edit the user's compositor configuration.
    Timer {
        id: floatingCheckTimer
        interval: 320
        repeat: false
        onTriggered: if (!floatHelper.running && root.visible) floatHelper.running = true
    }
    Process {
        id: floatHelper
        command: ["python3", Quickshell.shellPath("scripts/rustiq-settings-float.py")]
    }

    Item {
        anchors.fill: parent
        // No extra outside border or radius; Hyprland handles the window shape.
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 224
                Layout.fillHeight: true
                radius: 15
                color: Qt.alpha(Theme.foreground, 0.035)
                border.color: Theme.borderaccent
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 11
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 122
                        radius: 14
                        color: Qt.alpha(Theme.accent, 0.10)
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 14
                                color: Qt.alpha(Theme.accent, 0.12)
                                RusticQIcon { anchors.centerIn: parent; iconSize: 28 }
                            }
                            Item { Layout.fillHeight: true }
                            Text { text: Theme.useAether ? "AETHER SYNC" : "RUSTICQ"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(15) }
                            Text { text: "RUSTICQ DESKTOP  ·  " + ReleaseInfo.displayName.toUpperCase(); color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: [{key:"home", label:"All"}, {key:"ui", label:"UI"}, {key:"system", label:"System"}]
                            delegate: Rectangle {
                                id: groupChoice
                                required property var modelData
                                objectName: "settingsGroup_" + modelData.key
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.rowRadius
                                color: root.settingsGroup === modelData.key ? Qt.alpha(Theme.accent, 0.18) : Theme.surface
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label + " settings"
                                Accessible.onPressAction: root.navigate(modelData.key)
                                Keys.onReturnPressed: root.navigate(modelData.key)
                                Keys.onSpacePressed: root.navigate(modelData.key)
                                Text { anchors.centerIn: parent; text: groupChoice.modelData.label; color: root.settingsGroup === groupChoice.modelData.key ? Theme.accent : Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(groupChoice.modelData.key) }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 25
                        Text { text: root.settingsGroup === "system" ? "S Y S T E M" : root.settingsGroup === "ui" ? "U I  S E T T I N G S" : "A L L  S E T T I N G S"; font.family: Fonts.poppinsSB.name; color: Theme.muted; font.pixelSize: Fonts.scale(9) }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    }
                    Flickable {
                        id: navigationScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: navigationColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }
                        ColumnLayout {
                            id: navigationColumn
                            width: navigationScroll.width
                            spacing: 5
                    Repeater {
                        model: root.navigationPages
                        delegate: Rectangle {
                            id: navRow
                            required property var modelData
                            readonly property bool active: Store.settingsTab === modelData.key
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            radius: 12
                            color: active ? Qt.alpha(Theme.accent, 0.16) : navMouse.containsMouse ? Theme.surface : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 29; Layout.preferredHeight: 29; radius: 9
                                    color: active ? Qt.alpha(Theme.accent, 0.14) : Theme.surface
                                    Icon { anchors.centerIn: parent; icon: navRow.modelData.symbol; font.pixelSize: Fonts.scale(17); color: navRow.active ? Theme.accent : Theme.muted }
                                }
                                Text { text: navRow.modelData.label; Layout.fillWidth: true; color: Theme.foreground; font.family: navRow.active ? Fonts.poppinsSB.name : Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                                Rectangle { visible: navRow.active; Layout.preferredWidth: 4; Layout.preferredHeight: 18; radius: 3; color: Theme.accent }
                            }
                            MouseArea {
                                id: navMouse; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.navigate(navRow.modelData.key)
                            }
                        }
                    }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    Text {
                        text: "RUSTICQ · " + ReleaseInfo.displayName.toUpperCase() + "\nQuickshell " + ReleaseInfo.requiredQuickshell + "+"
                        Layout.fillWidth: true
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.rightMargin: openDeviceWindow.visible ? openDeviceWindow.width + 12 : 0
                        spacing: 3
                        Text { Layout.fillWidth: true; text: root.activePage.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(22); elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: "RUSTICQ / " + ReleaseInfo.displayName.toUpperCase() + " · " + root.activePage.detail; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: root.startSystemMove()
                    }
                    DeviceSettingsButton {
                        id: openDeviceWindow
                        objectName: "openFloatingDeviceSettings"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ["wifi", "bluetooth", "audio", "power"].indexOf(root.activePage.key) >= 0
                        kind: root.activePage.key
                        section: kind === "wifi" ? "details" : kind === "audio" ? "applications" : ""
                        label: "Open fullscreen"
                        iconOnly: true
                        fullscreen: true
                        symbol: "\ue5d0"
                        targetScreen: root.screen
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 43
                    radius: 12; color: Theme.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 13; spacing: 9
                        RusticQIcon { iconSize: 19 }
                        TextInput {
                            id: searchField
                            Layout.fillWidth: true; Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                            onTextEdited: root.query = text
                            clip: true
                            Text {
                                visible: searchField.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search all settings"
                                color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                            }
                        }
                        Rectangle {
                            visible: root.query.length > 0
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7
                            color: Theme.background
                            Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: Fonts.scale(16); color: Theme.foreground }
                            MouseArea { anchors.fill: parent; onClicked: { root.query = ""; searchField.text = ""; } }
                        }
                    }
                }
                Flickable {
                    id: contentView
                    visible: root.query.trim().length === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + 16 : 0
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn; width: 8 }
                    onVisibleChanged: if (visible) contentY = 0
                    Loader {
                        id: pageLoader
                        width: contentView.width
                        sourceComponent: Store.settingsTab === "home" || Store.settingsTab === "ui" || Store.settingsTab === "system" ? homePage :
                            Store.settingsTab === "wifi" ? wifiPage :
                            Store.settingsTab === "bluetooth" ? bluetoothPage :
                            Store.settingsTab === "audio" ? audioPage :
                            Store.settingsTab === "power" ? powerPage :
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
                ListView {
                    visible: root.query.trim().length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 8
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }
                    model: root.matched
                    delegate: Rectangle {
                        id: searchRow
                        required property var modelData
                        width: ListView.view.width; height: 66; radius: 12
                        color: itemMouse.containsMouse ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Icon { icon: "\ue8b6"; font.pixelSize: Fonts.scale(19); color: Theme.accent }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { text: searchRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                Text { text: searchRow.modelData.tab.toUpperCase() + " · " + searchRow.modelData.hint; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Icon { icon: "\ue5cc"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                        }
                        MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(searchRow.modelData.tab) }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 18
                    Icon { icon: "\ue5ca"; font.pixelSize: Fonts.scale(15); color: Theme.success }
                    Text { text: root.settingsGroup === "system" ? "Device changes use the system's network, Bluetooth and audio services" : "Interface changes save automatically · API keys remain in Linux keyring"; Layout.fillWidth: true; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); elide: Text.ElideRight }
                }
            }
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
    Component { id: appearancePage; SettingsAppearancePage {} }
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
