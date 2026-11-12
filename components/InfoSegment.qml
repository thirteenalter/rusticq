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
    property bool showSymbol: true
    property bool stacked: false
    property int captionMaximumWidth: -1
    property color symbolColor: Theme.foreground
    property int horizontalPadding: 3
    property int verticalPadding: 5
    signal activated()
    implicitWidth: segmentRow.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(28, segmentRow.implicitHeight + verticalPadding * 2)

    GridLayout {
        id: segmentRow
        anchors.centerIn: parent
        columns: root.stacked ? 1 : 2
        columnSpacing: Theme.barIconTextGap
        rowSpacing: 3
        Icon {
            visible: root.showSymbol
            icon: root.symbol
            font.pixelSize: Theme.barSymbolSize
            color: root.symbolColor
            Layout.preferredWidth: Theme.barIconSlotSize
            Layout.minimumWidth: Theme.barIconSlotSize
            Layout.maximumWidth: Theme.barIconSlotSize
            Layout.preferredHeight: Theme.barIconSlotSize
            Layout.alignment: Qt.AlignCenter
        }
        Text {
            text: root.caption
            textFormat: Text.PlainText
            visible: root.showCaption
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.barTextSize
            font.weight: Font.Medium
            color: Theme.foreground
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: root.stacked ? Text.Wrap : Text.NoWrap
            elide: root.stacked ? Text.ElideNone : Text.ElideRight
            Layout.maximumWidth: root.captionMaximumWidth < 0 ? Infinity : root.captionMaximumWidth
            Layout.alignment: Qt.AlignCenter
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
