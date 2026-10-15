import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../config"
import "../../components"
import "../../services"

// Shared card rhythm: 16px inset, 36px header, 12px gap, scrollable body.
Rectangle {
    id: root
    Layout.fillWidth: true
    property bool expanded: false
    Layout.preferredHeight: expanded ? 366 : 68
    radius: Theme.sectionRadius
    clip: true
    color: Qt.alpha(Theme.foreground, 0.02)
    border.width: 1
    border.color: Theme.borderaccent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 12

        SectionHeader {
            Layout.fillWidth: true
            title: "Battery"
            iconName: BatteryService.icon
            expanded: root.expanded
            onToggleRequested: root.expanded = !root.expanded
        }

        Flickable {
            id: batteryScroll
            visible: root.expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: body.implicitHeight + 8

            ColumnLayout {
                id: body
                width: batteryScroll.width
                spacing: 11

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: "Charge level"
                            font.family: Fonts.poppins.name
                            font.pixelSize: Theme.helperTextSize
                            color: Theme.muted
                        }
                        Text {
                            text: BatteryService.available ? BatteryService.percentage + "%" : "Unavailable"
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 18
                            color: Theme.foreground
                        }
                    }
                    Text {
                        text: BatteryService.status
                        font.family: Fonts.poppins.name
                        font.pixelSize: 11
                        color: BatteryService.charging ? Theme.success : Theme.muted
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7
                    radius: 4
                    color: Theme.surface
                    Rectangle {
                        width: parent.width * (BatteryService.available ? BatteryService.percentage / 100 : 0)
                        height: parent.height
                        radius: 4
                        color: BatteryService.charging ? Theme.success : Theme.accent
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: !BatteryService.available ? "Battery status unavailable" :
                          BatteryService.full ? "Fully charged" :
                          BatteryService.charging && BatteryService.timeToFull > 0 ?
                              "Time until full: " + Math.round(BatteryService.timeToFull / 60) + " min" :
                          BatteryService.status === "Discharging" && BatteryService.timeToEmpty > 0 ?
                              "Estimated remaining: " + Math.round(BatteryService.timeToEmpty / 60) + " min" : BatteryService.status
                    font.family: Fonts.poppins.name
                    font.pixelSize: Theme.helperTextSize
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.topMargin: 5
                    text: "Power mode"
                    color: Theme.foreground
                    font.pixelSize: 13
                    font.family: Fonts.poppinsSB.name
                }
                Repeater {
                    model: [
                        { title: "Power Saver", desc: "Lower energy usage", icon: "\uea35", mode: PowerProfile.PowerSaver },
                        { title: "Balanced", desc: "Everyday work", icon: "\ue9e4", mode: PowerProfile.Balanced },
                        { title: "Performance", desc: "Higher performance", icon: "\uea0b", mode: PowerProfile.Performance }
                    ]
                    delegate: Rectangle {
                        id: profileItem
                        required property var modelData
                        readonly property bool current: PowerProfiles.profile === modelData.mode
                        readonly property bool supported: modelData.mode !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: Theme.rowRadius
                        color: current ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                        opacity: supported ? 1 : 0.45
                        border.width: current ? 1 : 0
                        border.color: Theme.accent
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: Theme.sectionGap
                            Icon {
                                icon: profileItem.modelData.icon
                                font.pixelSize: 20
                                color: profileItem.current ? Theme.accent : Theme.muted
                                Layout.minimumWidth: 22
                                Layout.preferredWidth: 22
                                Layout.maximumWidth: 22
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: profileItem.modelData.title
                                    font.pixelSize: Theme.controlTextSize
                                    font.family: Fonts.poppinsSB.name
                                    color: Theme.foreground
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: profileItem.modelData.desc
                                    font.pixelSize: Theme.helperTextSize
                                    font.family: Fonts.poppins.name
                                    color: Theme.muted
                                }
                            }
                            Icon {
                                icon: "\ue5ca"
                                // Reserve the same trailing column for every profile.
                                opacity: profileItem.current ? 1 : 0
                                Layout.minimumWidth: 22
                                Layout.preferredWidth: 22
                                Layout.maximumWidth: 22
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: 19
                                color: Theme.accent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: profileItem.supported
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.profile = profileItem.modelData.mode
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: !PowerProfiles.hasPerformanceProfile ?
                          "Performance is unavailable from the system power-profile service." :
                          "Power profiles are managed by the system service."
                    font.family: Fonts.poppins.name
                    font.pixelSize: Theme.helperTextSize
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
