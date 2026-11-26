import QtQuick
import QtQuick.Controls.Basic
import "../../config"

ComboBox {
    id: root
    required property var design
    implicitHeight: 32
    implicitWidth: 190
    font.family: Fonts.poppins.name
    font.pixelSize: 13
    contentItem: Text {
        leftPadding: 10; rightPadding: 26
        text: root.displayText
        color: root.enabled ? root.design.foreground : root.design.muted
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text { x: root.width - width - 10; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: root.design.muted; font.pixelSize: 14 }
    background: Rectangle { radius: 7; color: root.design.background; border.width: 1; border.color: root.activeFocus ? root.design.accent : root.design.line }
    delegate: ItemDelegate {
        required property int index
        required property var modelData
        width: root.width
        implicitHeight: 32
        highlighted: root.highlightedIndex === index
        contentItem: Text { text: modelData; color: root.design.foreground; font: root.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: 5; color: parent.highlighted ? root.design.selected : "transparent" }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(260,contentItem.implicitHeight + 8)
        padding: 4
        contentItem: ListView { clip: true; implicitHeight: contentHeight; model: root.popup.visible ? root.delegateModel : null; currentIndex: root.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator {} }
        background: Rectangle { radius: 9; color: root.design.popover===undefined?root.design.background:root.design.popover; border.width: 1; border.color: root.design.line }
    }
}
