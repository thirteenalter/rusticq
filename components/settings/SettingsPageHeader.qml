import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var design
    property string title: ""
    property string description: ""
    property string symbol: "\ue8b8"
    spacing: 5
    RowLayout {
        Layout.fillWidth: true;spacing: 14
        SettingsCategoryIcon { design: root.design;symbol: root.symbol;iconSize: 44 }
        ColumnLayout {
            Layout.fillWidth: true;spacing: 3
            SettingsLabel { design: root.design;text: root.title;font.pixelSize: 27;font.bold: true;Layout.fillWidth: true }
            SettingsLabel { visible: !!root.description;design: root.design;text: root.description;color: design.muted;font.pixelSize: 12;wrapMode: Text.WordWrap;Layout.fillWidth: true }
        }
    }
}
