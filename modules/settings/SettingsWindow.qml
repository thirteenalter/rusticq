import QtQuick
import QtQuick.Layouts
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
    title: "RusticQ · Settings"
    implicitWidth: 940
    implicitHeight: 600
    minimumSize: Qt.size(760, 500)
    maximized: false
    fullscreen: false
    color: Theme.background
    property string query: ""
    readonly property var pages: [
        {key:"appearance", label:"Appearance", symbol:"\ue40a", detail:"Themes & palette"},
        {key:"bar", label:"Bar", symbol:"\ue30b", detail:"Layout & margins"},
        {key:"modules", label:"Modules", symbol:"\ue429", detail:"Indicators & menus"},
        {key:"widgets", label:"Widgets", symbol:"\ue916", detail:"Desktop cards"},
        {key:"dock", label:"Dock", symbol:"\ue8b8", detail:"Apps & auto-hide"},
        {key:"launcher", label:"App Launcher", symbol:"\ue8b6", detail:"Window & icon size"},
        {key:"display", label:"Displays", symbol:"\ue30b", detail:"Monitor arrangement"},
        {key:"os", label:"OS information", symbol:"\ue88e", detail:"Linux & session"},
        {key:"hardware", label:"Hardware", symbol:"\ue322", detail:"CPU, GPU & RAM"},
        {key:"apps", label:"Installed apps", symbol:"\ue5c3", detail:"Package inventory"},
        {key:"storage", label:"Storage", symbol:"\ue1db", detail:"Disks & maintenance"},
        {key:"updates", label:"Arch Updater", symbol:"\ue5d5", detail:"Packages & terminal"},
        {key:"ai", label:"AI Providers", symbol:"\uf371", detail:"Cloud assistant"},
        {key:"about", label:"About", symbol:"\ue88e", detail:"Project information"}
    ]
    readonly property var activePage: pages.find(p => p.key === Store.settingsTab) || pages[0]
    readonly property var searchItems: [
        {tab:"appearance", title:"Aether / Gruvbox color source", hint:"Theme, accent, palette"},
        {tab:"bar", title:"Bar position", hint:"Top Bottom Left Right"},
        {tab:"bar", title:"Bar layout and Clean Compact", hint:"Professional Compact Separated Simple Hover"},
        {tab:"bar", title:"Realtime margin editor", hint:"Spacing Edge Margin Slider"},
        {tab:"bar", title:"Icon spacing: Left, Center and Right", hint:"Per-icon spacing follows icon alignment; microphone wifi battery download upload all modes"},
        {tab:"bar", title:"Extra status icons", hint:"Microphone network download upload left center right"},
        {tab:"bar", title:"Bar icon alignment", hint:"Relocate every icon left center right clock wifi battery audio task quick control menu"},
        {tab:"modules", title:"App launcher and status modules", hint:"Icons Wifi Bluetooth Battery Audio Weather Clock"},
        {tab:"modules", title:"Menu bar and quick modes", hint:"Edit View Share File Shell Tools Night Silent"},
        {tab:"widgets", title:"Desktop widgets", hint:"Calendar Clock CPU RAM Music Media Now Playing Weather Connectivity Battery"},
        {tab:"dock", title:"Custom dock", hint:"Apps Auto-hide Files Browser"},
        {tab:"launcher", title:"App launcher dimensions", hint:"Window width height icon size favorites columns row height"},
        {tab:"display", title:"Monitor configuration", hint:"Resolution Refresh rate Scale Position"},
        {tab:"os", title:"Operating system information", hint:"Linux kernel distro hostname uptime session"},
        {tab:"hardware", title:"Hardware details", hint:"CPU GPU PCI motherboard RAM BIOS sensors"},
        {tab:"apps", title:"Installed applications", hint:"Pacman package list foreign explicit AUR install uninstall graphical application remove risk warning"},
        {tab:"storage", title:"Storage maintenance", hint:"Disk capacity filesystem mount cache journal"},
        {tab:"updates", title:"Arch Updater", hint:"Check updates upgrade downloads pacman progress logs terminal"},
        {tab:"ai", title:"AI provider setup", hint:"OpenAI Anthropic Claude Gemini API key"},
        {tab:"about", title:"About RusticQ", hint:"Version Quickshell"}
    ]
    readonly property var matched: searchItems.filter(item => (item.title + " " + item.hint + " " + item.tab).toLowerCase().indexOf(query.toLowerCase().trim()) !== -1)
    function navigate(tab) {
        Store.settingsTab = tab;
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
                            Text { text: Theme.useAether ? "AETHER SYNC" : "RUSTICQ"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 15 }
                            Text { text: "RUSTIQ DESKTOP  ·  ALPHA 4 RC2"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 9 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 25
                        Text { text: "S E T T I N G S"; font.family: Fonts.poppinsSB.name; color: Theme.muted; font.pixelSize: 9 }
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
                        ColumnLayout {
                            id: navigationColumn
                            width: navigationScroll.width
                            spacing: 5
                    Repeater {
                        model: root.pages
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
                                    Icon { anchors.centerIn: parent; icon: navRow.modelData.symbol; font.pixelSize: 17; color: navRow.active ? Theme.accent : Theme.muted }
                                }
                                Text { text: navRow.modelData.label; Layout.fillWidth: true; color: Theme.foreground; font.family: navRow.active ? Fonts.poppinsSB.name : Fonts.poppins.name; font.pixelSize: 12 }
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
                        text: "RUSTIQ · ALPHA 4 RC2\nQuickshell 0.3.1"
                        Layout.fillWidth: true
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
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
                        spacing: 3
                        Text { text: root.activePage.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 22 }
                        Text { text: "RUSTIQ / ALPHA 4 RC2 · " + root.activePage.detail; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: root.startSystemMove()
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
                            color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 12
                            onTextEdited: root.query = text
                            clip: true
                            Text {
                                visible: searchField.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search all settings"
                                color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            visible: root.query.length > 0
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7
                            color: Theme.background
                            Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: 16; color: Theme.foreground }
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
                    onVisibleChanged: if (visible) contentY = 0
                    Loader {
                        id: pageLoader
                        width: contentView.width
                        sourceComponent: Store.settingsTab === "appearance" ? appearancePage :
                            Store.settingsTab === "bar" ? barPage :
                            Store.settingsTab === "modules" ? modulesPage :
                            Store.settingsTab === "widgets" ? widgetsPage :
                            Store.settingsTab === "dock" ? dockPage :
                            Store.settingsTab === "launcher" ? launcherPage :
                            Store.settingsTab === "display" ? displayPage :
                            Store.settingsTab === "os" ? osPage :
                            Store.settingsTab === "hardware" ? hardwarePage :
                            Store.settingsTab === "apps" ? appsPage :
                            Store.settingsTab === "storage" ? storagePage :
                            Store.settingsTab === "updates" ? updatesPage :
                            Store.settingsTab === "ai" ? aiPage : aboutPage
                    }
                }
                ListView {
                    visible: root.query.trim().length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 8
                    model: root.matched
                    delegate: Rectangle {
                        id: searchRow
                        required property var modelData
                        width: ListView.view.width; height: 66; radius: 12
                        color: itemMouse.containsMouse ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Icon { icon: "\ue8b6"; font.pixelSize: 19; color: Theme.accent }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { text: searchRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 12 }
                                Text { text: searchRow.modelData.tab.toUpperCase() + " · " + searchRow.modelData.hint; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Icon { icon: "\ue5cc"; color: Theme.accent; font.pixelSize: 18 }
                        }
                        MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(searchRow.modelData.tab) }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 18
                    Icon { icon: "\ue5ca"; font.pixelSize: 15; color: Theme.success }
                    Text { text: "Changes saved automatically · API keys remain in Linux keyring"; Layout.fillWidth: true; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                }
            }
        }
    }
    Component { id: appearancePage; SettingsAppearancePage {} }
    Component { id: barPage; SettingsBarPage {} }
    Component { id: modulesPage; SettingsModulesPage {} }
    Component { id: widgetsPage; SettingsWidgetsPage {} }
    Component { id: dockPage; SettingsDockPage {} }
    Component { id: launcherPage; SettingsLauncherPage {} }
    Component { id: displayPage; SettingsDisplaysPage {} }
    Component { id: osPage; SettingsOSPage {} }
    Component { id: hardwarePage; SettingsHardwarePage {} }
    Component { id: appsPage; SettingsAppsPage {} }
    Component { id: storagePage; SettingsStoragePage {} }
    Component { id: updatesPage; SettingsUpdaterPage {} }
    Component { id: aiPage; SettingsAIPage {} }
    Component { id: aboutPage; SettingsAboutPage {} }
}
