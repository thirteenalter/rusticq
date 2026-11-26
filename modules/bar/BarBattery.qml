import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../config"
import "../../components"
import "../../services"

// Shared card rhythm: 16px inset, 36px header, 12px gap, scrollable body.
Rectangle {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    Layout.fillWidth: true
    property bool expanded: false
    property bool standalone: false
    property bool showSettingsButton: true
    property var targetScreen: null
    readonly property bool contentOpen: standalone || expanded
    Layout.preferredHeight: contentOpen ? 366 : root.settingsTheme.sectionHeaderHeight + root.settingsTheme.panelPadding * 2
    radius: root.settingsTheme.glassRadius("card", root.settingsTheme.sectionRadius)
    clip: true
    color: standalone && root.settingsTheme.glassEnabled ? "transparent" : root.settingsTheme.glassColor("card", Qt.alpha(root.settingsTheme.foreground, 0.02))
    border.width: standalone && root.settingsTheme.glassEnabled ? 0 : root.settingsTheme.glassBorderWidth("card", 1)
    border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.borderaccent)

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
                title: "Battery"
                iconName: BatteryService.icon
                expanded: root.contentOpen
                collapsible: !root.standalone
                onToggleRequested: if (!root.standalone) root.expanded = !root.expanded
            }
            DeviceSettingsButton {
                objectName: "powerFullscreenButton"
                visible: root.showSettingsButton
                kind: "power"
                section: "status"
                label: "Open battery settings"
                symbol: "\ue8b8"
                iconOnly: true
                fullscreen: false
                targetScreen: root.targetScreen
            }
        }

        Flickable {
            id: batteryScroll
            visible: root.contentOpen
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
                        GlassLabel {
                            text: "Charge level"
                            font.family: Fonts.poppins.name
                            font.pixelSize: root.settingsTheme.helperTextSize
                            color: root.settingsTheme.contentMuted
                        }
                        GlassLabel {
                            text: BatteryService.available ? BatteryService.percentage + "%" : "Unavailable"
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(18)
                            color: root.settingsTheme.foreground
                        }
                    }
                    GlassLabel {
                        text: BatteryService.status
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                        color: BatteryService.charging ? root.settingsTheme.success : root.settingsTheme.muted
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7
                    radius: 4
                    color: root.settingsTheme.surface
                    Rectangle {
                        width: parent.width * (BatteryService.available ? BatteryService.percentage / 100 : 0)
                        height: parent.height
                        radius: 4
                        color: BatteryService.charging ? root.settingsTheme.success : root.settingsTheme.accent
                    }
                }
                GlassLabel {
                    Layout.fillWidth: true
                    text: !BatteryService.available ? "Battery status unavailable" :
                          BatteryService.full ? "Fully charged" :
                          BatteryService.charging && BatteryService.timeToFull > 0 ?
                              "Time until full: " + Math.round(BatteryService.timeToFull / 60) + " min" :
                          BatteryService.status === "Discharging" && BatteryService.timeToEmpty > 0 ?
                              "Estimated remaining: " + Math.round(BatteryService.timeToEmpty / 60) + " min" : BatteryService.status
                    font.family: Fonts.poppins.name
                    font.pixelSize: root.settingsTheme.helperTextSize
                    color: root.settingsTheme.contentMuted
                    wrapMode: Text.WordWrap
                }

                GlassLabel {
                    Layout.topMargin: 5
                    text: "Power mode"
                    color: root.settingsTheme.foreground
                    font.pixelSize: Fonts.scale(13)
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
                        radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
                        color: root.settingsTheme.glassColor("card", current ? Qt.alpha(root.settingsTheme.accent, 0.13) : root.settingsTheme.surface)
                        opacity: supported ? 1 : 0.45
                        border.width: root.settingsTheme.glassBorderWidth("card", current ? 1 : 0)
                        border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.accent)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: root.settingsTheme.sectionGap
                            Icon {
                                icon: profileItem.modelData.icon
                                font.pixelSize: Fonts.scale(20)
                                color: profileItem.current ? root.settingsTheme.accent : root.settingsTheme.muted
                                Layout.minimumWidth: 22
                                Layout.preferredWidth: 22
                                Layout.maximumWidth: 22
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1
                                GlassLabel {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: profileItem.modelData.title
                                    font.pixelSize: root.settingsTheme.controlTextSize
                                    font.family: Fonts.poppinsSB.name
                                    color: root.settingsTheme.foreground
                                }
                                GlassLabel {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: profileItem.modelData.desc
                                    font.pixelSize: root.settingsTheme.helperTextSize
                                    font.family: Fonts.poppins.name
                                    color: root.settingsTheme.contentMuted
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
                                font.pixelSize: Fonts.scale(19)
                                color: root.settingsTheme.accent
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
                GlassLabel {
                    Layout.fillWidth: true
                    text: !PowerProfiles.hasPerformanceProfile ?
                          "Performance is unavailable from the system power-profile service." :
                          "Power profiles are managed by the system service."
                    font.family: Fonts.poppins.name
                    font.pixelSize: root.settingsTheme.helperTextSize
                    color: root.settingsTheme.contentMuted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
