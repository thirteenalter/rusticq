import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth as Native
import "../../config"
import "../../components"

// Explicit expanded geometry + clipped, scrollable body: never depends on the
// implicitHeight of children while they are invisible.
Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    Layout.fillWidth: true
    property bool expanded: false
    property bool standalone: false
    property bool showSettingsButton: true
    property var targetScreen: null
    readonly property bool contentOpen: standalone || expanded
    readonly property var adapter: Native.Bluetooth.defaultAdapter
    readonly property var availableDevices: adapter && adapter.enabled ? adapter.devices.values : []
    Layout.preferredHeight: contentOpen ? 336 : root.settingsTheme.sectionHeaderHeight + root.settingsTheme.panelPadding * 2
    radius: root.settingsTheme.glassRadius("card", root.settingsTheme.sectionRadius)
    color: standalone && root.settingsTheme.glassEnabled ? "transparent" : root.settingsTheme.glassColor("card", Qt.alpha(root.settingsTheme.foreground, 0.02))
    border.width: standalone && root.settingsTheme.glassEnabled ? 0 : root.settingsTheme.glassBorderWidth("card", 1)
    border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.borderaccent)
    clip: true

    onContentOpenChanged: if (!contentOpen) bluetoothSearch.text = ""
    onVisibleChanged: if (!visible) bluetoothSearch.text = ""
    onAdapterChanged: bluetoothSearch.text = ""
    Connections {
        target: root.adapter
        function onEnabledChanged() { if (!root.adapter.enabled) bluetoothSearch.text = ""; }
    }

    ColumnLayout {
        objectName: "surfaceContent"
        anchors.fill: parent
        anchors.margins: root.settingsTheme.sectionPadding
        spacing: root.settingsTheme.contentGap
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.maximumHeight: 36
            spacing: 8
            SectionHeader {
                Layout.fillWidth: true
                title: "Bluetooth"
                iconName: "\ue1a7"
                expanded: root.contentOpen
                collapsible: !root.standalone
                onToggleRequested: if (!root.standalone) root.expanded = !root.expanded
            }
            DeviceSettingsButton {
                objectName: "bluetoothFullscreenButton"
                visible: root.showSettingsButton
                kind: "bluetooth"
                section: "devices"
                label: "Open Bluetooth settings"
                symbol: "\ue8b8"
                iconOnly: true
                fullscreen: false
                targetScreen: root.targetScreen
            }
        }

        Flickable {
        id: bluetoothScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.contentOpen
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: bluetoothContent.implicitHeight + 10

        ColumnLayout {
            id: bluetoothContent
            width: bluetoothScroll.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                GlassLabel {
                    Layout.fillWidth: true
                    text: !root.adapter ? "No Bluetooth adapter" :
                          root.adapter.enabled ? "Bluetooth enabled" : "Bluetooth disabled"
                    color: root.settingsTheme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: root.settingsTheme.controlTextSize
                }
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 22
                    radius: 12
                    opacity: root.adapter ? 1 : 0.4
                    color: root.adapter && root.adapter.enabled ? root.settingsTheme.accent : root.settingsTheme.surface
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        x: root.adapter && root.adapter.enabled ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.settingsTheme.controlKnob
                        Behavior on x { enabled: root.settingsTheme.motionEnabled; NumberAnimation { duration: root.settingsTheme.motionFastDuration; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.adapter !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.adapter.enabled = !root.adapter.enabled
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                NameSearchField {
                    id: bluetoothSearch
                    objectName: "bluetoothNameSearch"
                    Layout.fillWidth: true
                    placeholder: "Search Bluetooth by name"
                    autoFocus: root.contentOpen
                    enabled: root.adapter !== null && root.adapter.enabled
                    onTextChanged: bluetoothScroll.contentY = 0
                }
                ScanButton {
                    enabled: root.adapter !== null && root.adapter.enabled
                    scanning: root.adapter !== null && root.adapter.discovering
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
            }

            Repeater {
                id: deviceList
                objectName: "bluetoothDeviceList"
                model: ScriptModel {
                    comparisonMode: ObjectComparison.Identity
                    values: {
                        const query = bluetoothSearch.query;
                        return root.availableDevices.filter(device => (device.name || device.address || "").toLowerCase().includes(query));
                    }
                }
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property var device: modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: root.settingsTheme.glassRadius("card", 11)
                    color: root.settingsTheme.glassColor("card", root.settingsTheme.surface)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 7
                        Icon { icon: "\ue337"; font.pixelSize: Fonts.scale(19); color: deviceRow.device.connected ? root.settingsTheme.accent : root.settingsTheme.muted }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            GlassLabel {
                                text: deviceRow.device.name || deviceRow.device.address
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: root.settingsTheme.foreground
                                font.pixelSize: Fonts.scale(11)
                                font.family: Fonts.poppinsSB.name
                            }
                            GlassLabel {
                                text: deviceRow.device.connected ? "Connected" :
                                      deviceRow.device.pairing ? "Pairing…" :
                                      deviceRow.device.paired ? "Paired" : "Available"
                                color: deviceRow.device.connected ? root.settingsTheme.success : root.settingsTheme.muted
                                font.pixelSize: Fonts.scale(10)
                                font.family: Fonts.poppins.name
                            }
                        }
                        GlassLabel {
                            visible: deviceRow.device.batteryAvailable
                            text: Math.round(deviceRow.device.battery * 100) + "%"
                            color: root.settingsTheme.contentMuted
                            font.pixelSize: Fonts.scale(10)
                        }
                        Rectangle {
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 30
                            radius: root.settingsTheme.glassRadius("card", 9)
                            color: root.settingsTheme.glassColor("card", deviceRow.device.connected ? root.settingsTheme.background : root.settingsTheme.accent)
                            GlassLabel {
                                anchors.centerIn: parent
                                text: deviceRow.device.connected ? "Disconnect" : deviceRow.device.paired ? "Connect" : "Pair"
                                color: deviceRow.device.connected ? root.settingsTheme.foreground : root.settingsTheme.background
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(10)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !deviceRow.device.pairing
                                onClicked: {
                                    if (deviceRow.device.connected) deviceRow.device.disconnect();
                                    else if (deviceRow.device.paired) deviceRow.device.connect();
                                    else deviceRow.device.pair();
                                }
                            }
                        }
                    }
                }
            }

            GlassLabel {
                Layout.fillWidth: true
                visible: deviceList.count === 0
                text: !root.adapter ? "No adapter found. Check BlueZ and rfkill." :
                      !root.adapter.enabled ? "Turn Bluetooth on to discover devices." :
                      bluetoothSearch.query.length > 0 && root.availableDevices.length > 0
                          ? "No matching devices. Try another name or clear the search." :
                      root.adapter.discovering ? "Scanning for nearby devices…" : "No devices found. Select Scan."
                color: root.settingsTheme.contentMuted
                wrapMode: Text.WordWrap
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(11)
            }
            GlassLabel {
                Layout.fillWidth: true
                text: "Pairing confirmation may require a Bluetooth agent such as blueman."
                color: root.settingsTheme.contentMuted
                wrapMode: Text.WordWrap
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }
    }
    }
}
