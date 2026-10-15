import QtQuick
import QtQuick.Layouts
import "../config"

// Shared accordion header: [Material icon] [title] [spacer] [chevron].
Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: 36
    height: 36
    property string iconName: "\ue8b8"
    property string title: "Section"
    property bool expanded: false
    signal toggleRequested()

    RowLayout {
        anchors.fill: parent
        spacing: Theme.sectionGap
        Icon {
            icon: root.iconName
            font.pixelSize: 20
            color: Theme.accent
            Layout.preferredWidth: 24
        }
        Text {
            Layout.fillWidth: true
            text: root.title
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Theme.sectionTitleSize
            color: Theme.foreground
            elide: Text.ElideRight
        }
        Icon {
            icon: "\ue5cf"
            font.pixelSize: 21
            Layout.preferredWidth: 23
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }
}
