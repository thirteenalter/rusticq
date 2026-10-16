import QtQuick
import QtQuick.Layouts
import "../config"

// Date, time and weather use the same Material icon, Poppins weight, tap
// target and alignment rules as the system status tray.
Item {
    id: root
    property string symbol: "\ue8b5"
    property string caption: ""
    property bool showCaption: true
    property color symbolColor: Theme.foreground
    property int horizontalPadding: 3
    property int verticalPadding: 5
    signal activated()
    implicitWidth: segmentRow.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(28, segmentRow.implicitHeight + verticalPadding * 2)

    RowLayout {
        id: segmentRow
        anchors.centerIn: parent
        spacing: Theme.barIconTextGap
        Icon {
            icon: root.symbol
            font.pixelSize: Theme.barSymbolSize
            color: root.symbolColor
            Layout.preferredWidth: Theme.barIconSlotSize
            Layout.minimumWidth: Theme.barIconSlotSize
            Layout.maximumWidth: Theme.barIconSlotSize
            Layout.preferredHeight: Theme.barIconSlotSize
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            text: root.caption
            visible: root.showCaption
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.barTextSize
            font.weight: Font.Medium
            color: Theme.foreground
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
