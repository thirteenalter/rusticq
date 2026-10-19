import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// One local photo at a time; no external image URLs and no always-on scanner.
Rectangle {
    id: root
    property string imageUri: ""
    property string imageName: ""
    property string status: ""
    property int fileCount: 0
    readonly property string helper: Quickshell.shellPath("scripts/rusticq-widget-images.py")
    implicitHeight: imageArea.implicitHeight + 28
    radius: 17
    color: Theme.background
    border.color: Theme.borderaccent
    border.width: 1
    function next() {
        if (imageProcess.running) return;
        const args = ["python3", helper, "--folder", SettingsStore.widgetImageFolder];
        if (imageName) args.push("--previous", imageName);
        imageProcess.exec(args);
    }
    Process {
        id: imageProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(this.text);
                if (result.ok === true && String(result.uri).startsWith("file://")) {
                    root.imageUri = result.uri;
                    root.imageName = result.name;
                    root.fileCount = result.count;
                    root.status = "";
                } else {
                    root.imageUri = "";
                    root.status = result.message || "Unable to select image";
                }
            } catch (error) { root.imageUri = ""; root.status = "Image selection failed"; }
        } }
    }
    // Timer exists only while the actual desktop widget is instantiated.
    Timer {
        interval: SettingsStore.widgetImageRotateSeconds * 1000
        running: SettingsStore.widgetImageRotateSeconds > 0 && root.visible
        repeat: true
        onTriggered: root.next()
    }
    // Reactive binding works even when QML cannot resolve a notify signal
    // through Connections on the dynamically registered SettingsStore singleton.
    property string activeFolder: SettingsStore.widgetImageFolder
    onActiveFolderChanged: { imageName = ""; next(); }
    Component.onCompleted: next()
    ColumnLayout {
        id: imageArea
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 13
        spacing: 9
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Icon { icon: "\ue3f4"; color: Theme.accent; font.pixelSize: Fonts.scale(19) }
            Text { Layout.fillWidth: true; text: "Random Image"; color: Theme.foreground
                font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 188
            radius: 10; color: Theme.surface; clip: true
            Image {
                anchors.fill: parent
                asynchronous: true
                source: root.imageUri
                fillMode: Image.PreserveAspectCrop
                cache: false
                sourceSize.width: Math.max(160, width * 2)
                sourceSize.height: Math.max(100, height * 2)
            }
            Column {
                anchors.centerIn: parent; spacing: 6
                visible: !root.imageUri
                Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "\ue3f4"
                    color: Theme.muted; font.pixelSize: Fonts.scale(26) }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: root.status || "Select a folder in Settings → Widgets"
                    width: 220; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.imageName || "Local photos only"
                elide: Text.ElideMiddle; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
            Text { text: root.fileCount ? root.fileCount + " images" : ""; color: Theme.accent; font.pixelSize: Fonts.scale(9) }
            Rectangle {
                Layout.preferredWidth: 58; Layout.preferredHeight: 27; radius: 8; color: Theme.surface
                Text { anchors.centerIn: parent; text: "Next ↻"; color: Theme.accent; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !imageProcess.running
                    cursorShape: Qt.PointingHandCursor; onClicked: root.next() }
            }
        }
    }
}
