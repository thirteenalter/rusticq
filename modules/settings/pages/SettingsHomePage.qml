import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    property string group: "home"
    property var catalog: []
    property var systemPages: []
    signal navigateRequested(string tab)
    spacing: Theme.sectionGap
    readonly property var categories: [
        {key:"ui", label:"UI settings", symbol:"\ue40a", detail:"Appearance, bar, dock, widgets, launcher and RusticQ preferences"},
        {key:"system", label:"System settings", symbol:"\ue8b8", detail:"Wi-Fi, Bluetooth, audio, battery, displays and Linux devices"}
    ]
    readonly property var shownPages: catalog.filter(page => ["home", "ui", "system"].indexOf(page.key) < 0
        && (group === "home" || (systemPages.indexOf(page.key) >= 0 ? "system" : "ui") === group))

    SettingsSection {
        heading: root.group === "home" ? "Your desktop settings" : root.group === "system" ? "System settings" : "UI settings"
        description: root.group === "home" ? "Choose interface customization or system controls. Search above works across every page."
            : root.group === "system" ? "Manage connections, sound and devices from one place."
            : "Customize the desktop interface, including the bar, without changing device settings."
        symbol: root.group === "ui" ? "\ue40a" : "\ue8b8"
        GridLayout {
            visible: root.group === "home"
            Layout.fillWidth: true
            columns: width > 620 ? 2 : 1
            columnSpacing: Theme.sectionGap
            rowSpacing: Theme.sectionGap
            Repeater {
                model: root.categories
                delegate: Rectangle {
                    id: category
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: categoryContent.implicitHeight + 28
                    radius: Theme.rowRadius
                    color: Qt.alpha(Theme.accent, 0.12)
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    Accessible.onPressAction: root.navigateRequested(modelData.key)
                    Keys.onReturnPressed: root.navigateRequested(modelData.key)
                    Keys.onSpacePressed: root.navigateRequested(modelData.key)
                    ColumnLayout {
                        id: categoryContent
                        x: 14; y: 14; width: parent.width - 28
                        spacing: 8
                        Icon { icon: category.modelData.symbol; color: Theme.accent; font.pixelSize: Fonts.scale(25) }
                        Text { text: category.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(15) }
                        Text { Layout.fillWidth: true; text: category.modelData.detail; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Theme.helperTextSize }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateRequested(category.modelData.key) }
                }
            }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width > 620 ? 2 : 1
        columnSpacing: Theme.sectionGap
        rowSpacing: Theme.sectionGap
        Repeater {
            model: root.shownPages
            delegate: Rectangle {
                id: tile
                required property var modelData
                objectName: "settingsTile_" + modelData.key
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                radius: Theme.rowRadius
                color: tileMouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : Theme.surface
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: root.navigateRequested(modelData.key)
                Keys.onReturnPressed: root.navigateRequested(modelData.key)
                Keys.onSpacePressed: root.navigateRequested(modelData.key)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Icon { icon: tile.modelData.symbol; color: Theme.accent; font.pixelSize: Fonts.scale(22) }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { Layout.fillWidth: true; text: tile.modelData.label; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Theme.controlTextSize }
                        Text { Layout.fillWidth: true; text: tile.modelData.detail; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Theme.helperTextSize }
                    }
                    Icon { icon: "\ue5cc"; color: Theme.muted; font.pixelSize: Fonts.scale(18) }
                }
                MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.navigateRequested(tile.modelData.key) }
            }
        }
    }
}
