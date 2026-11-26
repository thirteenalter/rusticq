import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    id: root
    required property var design
    property string value: ""
    property string format: "hex"
    signal edited(string value)
    spacing: 6
    function colorValue() {
        if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
        const encoded = /^0x[0-9a-fA-F]{8}$/.test(value) ? "rgba("+value.slice(4)+value.slice(2,4)+")" : value;
        const match = /^(rgba?)\(([0-9a-fA-F]+)\)$/.exec(encoded);
        if (!match || (match[2].length !== 6 && match[2].length !== 8)) return design.accent;
        const hex=match[2];
        return Qt.rgba(parseInt(hex.slice(0,2),16)/255,parseInt(hex.slice(2,4),16)/255,parseInt(hex.slice(4,6),16)/255,hex.length===8 ? parseInt(hex.slice(6,8),16)/255 : 1);
    }
    SettingsTextField { design: root.design; Layout.fillWidth: true; text: root.value; placeholderText:root.format==="hex"?"#RRGGBB":"rgba(RRGGBBAA)"; onEditingFinished: root.edited(text) }
    SettingsButton {
        design: root.design; text: ""; implicitWidth: 30
        Accessible.name: "Choose color"
        Rectangle { anchors.centerIn: parent; width: 17; height: 17; radius: 5; color: root.colorValue(); border.color: root.design.line; border.width: 1 }
        onClicked: { dialog.selectedColor=root.colorValue(); dialog.open(); }
    }
    ColorDialog {
        id: dialog
        title: "Choose color"
        options: ColorDialog.ShowAlphaChannel
        onAccepted: {
            function hex(v) { return Math.round(v*255).toString(16).padStart(2,"0"); }
            root.edited(root.format==="hex" ? "#"+hex(selectedColor.r)+hex(selectedColor.g)+hex(selectedColor.b) : "rgba("+hex(selectedColor.r)+hex(selectedColor.g)+hex(selectedColor.b)+hex(selectedColor.a)+")");
        }
    }
}
