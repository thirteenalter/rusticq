import QtQuick
import QtQuick.Layouts
import "../config"

// Shared accordion header: [Material icon] [title] [spacer] [chevron].
Item {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    Layout.fillWidth: true
    implicitHeight: subtitle.length ? 48 : 36
    height: implicitHeight
    property string iconName: "\ue8b8"
    property string title: "Section"
    property string subtitle: ""
    property bool expanded: false
    // In single-widget popups this becomes a static section title.
    property bool collapsible: true
    signal toggleRequested()

    RowLayout {
        anchors.fill: parent
        spacing: root.settingsTheme.sectionGap
        Icon {
            icon: root.iconName
            font.pixelSize: Fonts.scale(20)
            color: root.settingsTheme.accent
            Layout.preferredWidth: 24
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1
            GlassLabel {
                Layout.fillWidth: true
                text: root.title
                font.family: Fonts.poppinsSB.name
                font.pixelSize: root.settingsTheme.sectionTitleSize
                color: root.settingsTheme.foreground
                elide: Text.ElideRight
            }
            GlassLabel {
                visible: root.subtitle.length > 0
                Layout.fillWidth: true
                text: root.subtitle
                color: root.settingsTheme.contentMuted
                font.family: Fonts.poppins.name
                font.pixelSize: root.settingsTheme.helperTextSize
                elide: Text.ElideRight
            }
        }
        Icon {
            visible: root.collapsible
            icon: "\ue5cf"
            font.pixelSize: Fonts.scale(21)
            Layout.preferredWidth: 23
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { enabled: root.settingsTheme.motionEnabled; NumberAnimation { duration: root.settingsTheme.motionFastDuration; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.collapsible
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }
}
