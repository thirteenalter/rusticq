import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "pages"

// RC5 settings repair: each independent page has a real implicitHeight.
// No overlapping/zero-height cards, and no single overloaded Bar page.
FloatingWindow {
    id: root
    visible: Store.settingsVisible
    title: "RusticQ · Settings"
    implicitWidth: 1130
    implicitHeight: 750
    color: Theme.background
    property string query: ""
    readonly property var pages: [
        {key:"appearance", label:"Appearance", symbol:"\ue40a", detail:"Themes & palette"},
        {key:"bar", label:"Bar", symbol:"\ue30b", detail:"Layout & margins"},
        {key:"modules", label:"Modules", symbol:"\ue429", detail:"Indicators & menus"},
        {key:"widgets", label:"Widgets", symbol:"\ue916", detail:"Desktop cards"},
        {key:"dock", label:"Dock", symbol:"\ue8b8", detail:"Apps & auto-hide"},
        {key:"display", label:"Displays", symbol:"\ue30b", detail:"Monitor arrangement"},
        {key:"ai", label:"AI Providers", symbol:"\ue8f4", detail:"Cloud assistant"},
        {key:"about", label:"About", symbol:"\ue88e", detail:"Project information"}
    ]
    readonly property var activePage: pages.find(p => p.key === Store.settingsTab) || pages[0]
    readonly property var searchItems: [
        {tab:"appearance", title:"Aether / Gruvbox color source", hint:"Theme, accent, palette"},
        {tab:"bar", title:"Bar position", hint:"Top Bottom Left Right"},
        {tab:"bar", title:"Bar layout and Clean Compact", hint:"Professional Compact Separated Simple Hover"},
        {tab:"bar", title:"Realtime margin editor", hint:"Spacing Edge Margin Slider"},
        {tab:"modules", title:"App launcher and status modules", hint:"Icons Wifi Bluetooth Battery Audio Weather Clock"},
        {tab:"modules", title:"Menu bar and quick modes", hint:"Edit View Share File Shell Tools Night Silent"},
        {tab:"widgets", title:"Desktop widgets", hint:"Calendar Clock CPU RAM Music Media Now Playing Weather Connectivity Battery"},
        {tab:"dock", title:"Custom dock", hint:"Apps Auto-hide Files Browser"},
        {tab:"display", title:"Monitor configuration", hint:"Resolution Refresh rate Scale Position"},
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
    onVisibleChanged: if (!visible) Store.settingsVisible = false

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.background
        border.width: 1
        border.color: Theme.borderaccent
        clip: true
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 258
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
                                Layout.preferredWidth: 41
                                Layout.preferredHeight: 41
                                radius: 13
                                color: Qt.alpha(Theme.accent, 0.20)
                                Icon { anchors.centerIn: parent; icon: "\ue8b8"; color: Theme.accent; font.pixelSize: 24 }
                            }
                            Item { Layout.fillHeight: true }
                            Text { text: Theme.useAether ? "AETHER SYNC" : "RUSTICQ"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 15 }
                            Text { text: "RUSTIQ DESKTOP  ·  ALPHA 3 RC5"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 9 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 25
                        Text { text: "S E T T I N G S"; font.family: Fonts.poppinsSB.name; color: Theme.muted; font.pixelSize: 9 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    }
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
                    Item { Layout.fillHeight: true }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                    Text {
                        text: "RUSTIQ · ALPHA 3 RC5\nQuickshell 0.3.1"
                        Layout.fillWidth: true
                        color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: root.activePage.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 22 }
                        Text { text: "RUSTIQ / ALPHA 3 RC5 · " + root.activePage.detail; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                    }
                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        radius: 11; color: Theme.surface
                        Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.foreground; font.pixelSize: 20 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.settingsVisible = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 43
                    radius: 12; color: Theme.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 13; spacing: 9
                        Icon { icon: "\ue8b6"; font.pixelSize: 19; color: Theme.accent }
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
                            Store.settingsTab === "display" ? displayPage :
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
    Component { id: displayPage; SettingsDisplaysPage {} }
    Component { id: aiPage; SettingsAIPage {} }
    Component { id: aboutPage; SettingsAboutPage {} }
}
