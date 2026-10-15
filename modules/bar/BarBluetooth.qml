import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as Native
import "../../config"
import "../../components"

// Explicit expanded geometry + clipped, scrollable body: never depends on the
// implicitHeight of children while they are invisible.
Rectangle {
    id: root
    Layout.fillWidth: true
    property bool expanded: false
    readonly property var adapter: Native.Bluetooth.defaultAdapter
    Layout.preferredHeight: expanded ? 336 : 68
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.02)
    border.width: 1
    border.color: Theme.borderaccent
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 12
        SectionHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            iconName: "\ue1a7"
            expanded: root.expanded
            onToggleRequested: root.expanded = !root.expanded
        }

        Flickable {
        id: bluetoothScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.expanded
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
                Text {
                    Layout.fillWidth: true
                    text: !root.adapter ? "No Bluetooth adapter" :
                          root.adapter.enabled ? "Bluetooth enabled" : "Bluetooth disabled"
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Theme.controlTextSize
                }
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 22
                    radius: 12
                    opacity: root.adapter ? 1 : 0.4
                    color: root.adapter && root.adapter.enabled ? Theme.accent : Theme.surface
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        x: root.adapter && root.adapter.enabled ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        Behavior on x { NumberAnimation { duration: 140 } }
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
                Text {
                    text: "Devices"
                    Layout.fillWidth: true
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: 12
                }
                ScanButton {
                    enabled: root.adapter !== null && root.adapter.enabled
                    scanning: root.adapter !== null && root.adapter.discovering
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
            }

            Repeater {
                model: root.adapter && root.adapter.enabled ? root.adapter.devices : null
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property var device: modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 11
                    color: Theme.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 7
                        Icon { icon: "\ue337"; font.pixelSize: 19; color: deviceRow.device.connected ? Theme.accent : Theme.muted }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: deviceRow.device.name || deviceRow.device.address
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: Theme.foreground
                                font.pixelSize: 11
                                font.family: Fonts.poppinsSB.name
                            }
                            Text {
                                text: deviceRow.device.connected ? "Connected" :
                                      deviceRow.device.pairing ? "Pairing…" :
                                      deviceRow.device.paired ? "Paired" : "Available"
                                color: deviceRow.device.connected ? Theme.success : Theme.muted
                                font.pixelSize: 10
                                font.family: Fonts.poppins.name
                            }
                        }
                        Text {
                            visible: deviceRow.device.batteryAvailable
                            text: Math.round(deviceRow.device.battery * 100) + "%"
                            color: Theme.muted
                            font.pixelSize: 10
                        }
                        Rectangle {
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 30
                            radius: 9
                            color: deviceRow.device.connected ? Theme.background : Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: deviceRow.device.connected ? "Disconnect" : deviceRow.device.paired ? "Connect" : "Pair"
                                color: deviceRow.device.connected ? Theme.foreground : Theme.background
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: 10
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

            Text {
                Layout.fillWidth: true
                visible: !root.adapter || !root.adapter.enabled || root.adapter.devices.values.length === 0
                text: !root.adapter ? "No adapter found. Check BlueZ and rfkill." :
                      !root.adapter.enabled ? "Turn Bluetooth on to discover devices." :
                      root.adapter.discovering ? "Scanning for nearby devices…" : "No devices found. Select Scan."
                color: Theme.muted
                wrapMode: Text.WordWrap
                font.family: Fonts.poppins.name
                font.pixelSize: 11
            }
            Text {
                Layout.fillWidth: true
                text: "Pairing confirmation may require a Bluetooth agent such as blueman."
                color: Theme.muted
                wrapMode: Text.WordWrap
                font.family: Fonts.poppins.name
                font.pixelSize: 10
            }
        }
    }
    }
}
