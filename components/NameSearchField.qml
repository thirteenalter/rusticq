import QtQuick
import QtQuick.Layouts
import "../config"

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: "Search by name"
    readonly property string query: text.trim().toLowerCase()
    implicitHeight: 34
    implicitWidth: 220
    radius: Theme.rowRadius
    color: Theme.background
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.borderaccent
    opacity: enabled ? 1 : 0.45
    Behavior on border.color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 5
        spacing: 6
        Icon { icon: "\ue8b6"; color: Theme.muted; font.pixelSize: Fonts.scale(16) }
        TextInput {
            id: input
            objectName: "nameSearchInput"
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            font.family: Fonts.poppins.name
            font.pixelSize: Theme.helperTextSize
            selectByMouse: true
            activeFocusOnTab: true
            clip: true
            Accessible.name: root.placeholder
            Keys.onEscapePressed: event => {
                if (text.length > 0) text = "";
                else event.accepted = false;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: input.text.length === 0
                text: root.placeholder
                elide: Text.ElideRight
                color: Theme.muted
                font: input.font
            }
        }
        ActionButton {
            objectName: "clearNameSearch"
            visible: root.text.length > 0
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            symbol: "\ue5cd"
            Accessible.name: "Clear search"
            onClicked: {
                root.text = "";
                input.forceActiveFocus();
            }
        }
    }
}
