import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var design
    property var window
    property string title: ""
    property bool canBack: false
    property bool canForward: false
    signal back()
    signal forward()
    default property alias actions: actionRow.data
    implicitHeight: 54
    MouseArea { anchors.fill: parent;onPressed: if(root.window)root.window.startSystemMove();onDoubleClicked: if(root.window)root.window.maximized=!root.window.maximized }
    RowLayout {
        anchors.fill: parent;anchors.leftMargin: 20;anchors.rightMargin: 24;spacing: 8
        SettingsButton { design: root.design;text:"‹";enabled: root.canBack;Accessible.name:"Back";onClicked:root.back() }
        SettingsButton { design: root.design;text:"›";enabled: root.canForward;Accessible.name:"Forward";onClicked:root.forward() }
        SettingsLabel { design: root.design;text: root.title;Layout.fillWidth: true;Layout.leftMargin: 10;font.bold: true;font.pixelSize: 14 }
        RowLayout { id: actionRow;spacing: 8 }
    }
    Rectangle { anchors.bottom: parent.bottom;width: parent.width;height: 1;color: root.design.line }
}
