import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// Unlike the RC5 cards, the root's intrinsic height is derived from its content.
// It is safe to use inside a ColumnLayout in a Flickable.
Rectangle {
    id: section
    default property alias controls: content.data
    property string heading: ""
    property string description: ""
    property string symbol: "\ue8b8"
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 30
    radius: 15
    color: Theme.surface
    border.width: 1
    border.color: Theme.borderaccent

    ColumnLayout {
        id: content
        x: 15
        y: 15
        width: Math.max(0, section.width - 30)
        spacing: 11
        RowLayout {
            visible: section.heading.length > 0
            Layout.fillWidth: true
            spacing: 11
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 11
                color: Qt.alpha(Theme.accent, 0.14)
                Icon { anchors.centerIn: parent; icon: section.symbol; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: section.heading; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(14); color: Theme.foreground }
                Text {
                    visible: section.description.length > 0
                    Layout.fillWidth: true
                    text: section.description
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
                }
            }
        }
    }
}
