import QtQuick
import QtQuick.Controls.Basic
import "../../config"
import "../"

Item {
    id: root
    required property var design
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""
    property string accessibleName: "Value"
    readonly property int decimals: Math.min(4, (String(stepSize).split(".")[1] || "").length)
    readonly property string formattedValue: Number(value).toFixed(decimals) + suffix
    signal edited(real value)
    implicitWidth: 96
    implicitHeight: 30

    function commit(candidate) {
        if (!Number.isFinite(candidate) || stepSize <= 0) {
            field.text = formattedValue;
            return;
        }
        const snapped = from + Math.round((candidate - from) / stepSize) * stepSize;
        edited(Number(Math.max(from, Math.min(to, snapped)).toFixed(decimals)));
        field.text = formattedValue;
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.design.interactive
        border.width: 1
        border.color: field.activeFocus ? root.design.accent : root.design.line
    }
    TextField {
        id: field
        objectName: "settings-number-field"
        anchors.fill: parent
        anchors.rightMargin: 24
        font.family: Fonts.poppins.name
        font.pixelSize: 13
        color: root.design.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        selectByMouse: true
        leftPadding: 5
        rightPadding: 2
        background: null
        Accessible.name: root.accessibleName
        onEditingFinished: root.commit(parseFloat(text))
        Keys.onUpPressed: root.commit(root.value + root.stepSize)
        Keys.onDownPressed: root.commit(root.value - root.stepSize)
        Keys.onEscapePressed: text = root.formattedValue
    }
    Binding {
        target: field
        property: "text"
        value: root.formattedValue
        when: !field.activeFocus
        restoreMode: Binding.RestoreNone
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 23
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        width: 1
        color: root.design.line
    }
    Repeater {
        model: 2
        delegate: Button {
            required property int index
            objectName: index === 0 ? "settings-number-increase" : "settings-number-decrease"
            x: root.width - 23
            y: index * root.height / 2
            width: 23
            height: root.height / 2
            padding: 0
            enabled: index === 0 ? root.value < root.to : root.value > root.from
            Accessible.name: (index === 0 ? "Increase " : "Decrease ") + root.accessibleName
            onClicked: root.commit(root.value + (index === 0 ? root.stepSize : -root.stepSize))
            background: Rectangle {
                radius: 4
                color: parent.down ? root.design.selected : parent.hovered ? root.design.hover : "transparent"
            }
            contentItem: Icon {
                icon: parent.index === 0 ? "\ue5ce" : "\ue5cf"
                color: parent.enabled ? root.design.foreground : root.design.muted
                font.pixelSize: 14
            }
        }
    }
}
