import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../../components/settings" as Suite

ColumnLayout {
    id: root
    required property var palette
    required property var option
    objectName: "hypr-option-" + option.id
    property bool highlighted: false
    readonly property var current: HyprlandConfigService.value(option.id)
    readonly property bool supported: option.supported && HyprlandConfigService.editable
    readonly property bool dependencyEnabled: !option.dependencies || HyprlandConfigService.value(option.dependencies) !== false
    spacing: 0
    Layout.fillWidth: true
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(root.palette.rowHeight, row.implicitHeight + 12)
        color: root.highlighted ? root.palette.selected : "transparent"
        radius: 8
        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: 6
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                HyprSettingsLabel { palette: root.palette; text: root.option.label; Layout.fillWidth: true }
                HyprSettingsLabel {
                    visible: !root.supported || root.option.description!==root.option.id
                    palette: root.palette; color: palette.muted; font.pixelSize: 12
                    text: root.supported ? root.option.description : root.option.reason || "Unavailable in this session"
                    Layout.fillWidth: true
                }
            }
            Loader {
                Layout.preferredWidth: root.option.type === "bool" ? 44 : root.option.type === "string" ? 185 : Math.max(200,root.width*0.46)
                Layout.alignment: Qt.AlignVCenter
                enabled: root.supported && root.dependencyEnabled && !HyprlandConfigService.busy
                opacity: enabled ? 1 : 0.45
                sourceComponent: root.option.type === "bool" ? toggle : root.option.choices.length ? choices : root.option.label.toLowerCase().includes("color") ? colorPicker : root.option.type === "string" ? field : range
            }
            HyprSettingsButton {
                palette: root.palette; text: "↶"; implicitWidth: 28
                enabled: root.supported && !HyprlandConfigService.busy
                Accessible.name: (root.option.defaultKnown ? "Reset to default: " : "Remove override: ") + root.option.label
                onClicked: HyprlandConfigService.resetOption(root.option.id)
                ToolTip.visible: hovered
                ToolTip.text: root.option.defaultKnown ? "Reset to the compositor-reported default" : "Remove the RusticQ override; use your existing configuration"
            }
        }
    }
    Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; implicitHeight: 1; color: root.palette.line }
    Component {
        id: toggle
        Switch {
            id: switchControl
            checked: root.current === true
            Accessible.name: root.option.label
            onToggled: HyprlandConfigService.setOption(root.option.id, checked)
            indicator: Rectangle {
                implicitWidth: 36; implicitHeight: 21; radius: 11
                color: switchControl.checked ? root.palette.accent : root.palette.line
                Rectangle { x: switchControl.checked ? 17 : 3; y: 3; width: 15; height: 15; radius: 8; color: "white"; Behavior on x { NumberAnimation { duration: root.palette.duration } } }
            }
        }
    }
    Component {
        id: field
        HyprSettingsField {
            palette: root.palette
            text: root.current === null || root.current === undefined ? "" : String(root.current)
            placeholderText: "Unmeasured / complex value"
            Accessible.name: root.option.label
            onEditingFinished: if (text !== String(root.current)) HyprlandConfigService.setOption(root.option.id, text)
        }
    }
    Component {
        id: choices
        HyprSettingsDropdown {
            colors: root.palette
            model: root.option.choices
            currentIndex: Math.max(-1, model.indexOf(root.current))
            Accessible.name: root.option.label
            onActivated: HyprlandConfigService.setOption(root.option.id, currentText)
        }
    }
    Component {
        id: colorPicker
        HyprSettingsColorPicker { palette: root.palette; value: root.current === null || root.current === undefined ? "" : String(root.current); onEdited: value => HyprlandConfigService.setOption(root.option.id,value) }
    }
    Component {
        id: range
        Suite.SettingsSlider {
            design:root.palette
            accessibleName:root.option.label
            readonly property bool percent:root.option.id.indexOf("opacity")>=0
            from:root.option.minimum*(percent?100:1);to:root.option.maximum*(percent?100:1)
            stepSize:percent || root.option.type==="int"?1:0.01
            value:root.current===null || root.current===undefined?from:Number(root.current)*(percent?100:1)
            suffix:percent?" %":root.option.id==="decoration:rounding" || root.option.id.indexOf("gaps")>=0 || root.option.id==="general:border_size"?" px":""
            onEdited:value=>HyprlandConfigService.setOption(root.option.id,percent?value/100:root.option.type==="int"?Math.round(value):Math.round(value*100)/100)
        }
    }
}
