import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"

Rectangle {
    id: root
    signal launched()
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.03)
    border.color: Theme.borderaccent
    property string query: ""

    function textOf(value) {
        return value === undefined || value === null ? "" : String(value);
    }
    function matches(entry) {
        const q = query.trim().toLowerCase();
        if (!q.length) return true;
        const haystack = [
            textOf(entry.name),
            textOf(entry.genericName),
            textOf(entry.comment),
            textOf(entry.id),
            Array.isArray(entry.keywords) ? entry.keywords.join(" ") : ""
        ].join(" ").toLowerCase();
        return haystack.indexOf(q) !== -1;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.alpha(Theme.accent, 0.15)
                Icon { anchors.centerIn: parent; icon: "\ue8b6"; font.pixelSize: 20; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "App Launcher"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 15 }
                Text { text: "Search installed applications"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: 10 }
            }
            Text {
                text: DesktopEntries.applications.count + " apps"
                color: Theme.muted
                font.family: Fonts.poppins.name
                font.pixelSize: 10
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 11
            color: Theme.surface
            border.color: Qt.alpha(Theme.foreground, 0.05)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Icon { icon: "\ue8b6"; color: Theme.accent; font.pixelSize: 18 }
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.35)
                    selectedTextColor: Theme.foreground
                    font.family: Fonts.poppins.name
                    font.pixelSize: 12
                    text: root.query
                    onTextEdited: root.query = text
                    Component.onCompleted: forceActiveFocus()
                }
                Text {
                    visible: searchField.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type to search apps"
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 11
                }
                Rectangle {
                    visible: root.query.length > 0
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 7
                    color: Qt.alpha(Theme.accent, 0.12)
                    Icon { anchors.centerIn: parent; icon: "\ue5cd"; font.pixelSize: 16; color: Theme.foreground }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.query = ""; searchField.text = ""; searchField.forceActiveFocus(); }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.borderaccent
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: DesktopEntries.applications
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: appRow
                required property var modelData
                readonly property bool matched: root.matches(modelData)
                width: ListView.view.width
                height: matched ? 56 : 0
                visible: height > 0
                radius: 12
                color: appMouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : Theme.surface
                border.width: appMouse.containsMouse ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.35)

                Behavior on height { NumberAnimation { duration: 90 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.11)
                        Text {
                            anchors.centerIn: parent
                            text: root.textOf(appRow.modelData.name).length ? root.textOf(appRow.modelData.name).charAt(0).toUpperCase() : "•"
                            color: Theme.accent
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 15
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: root.textOf(appRow.modelData.name)
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.textOf(appRow.modelData.genericName) || root.textOf(appRow.modelData.comment) || root.textOf(appRow.modelData.id)
                            color: Theme.muted
                            font.family: Fonts.poppins.name
                            font.pixelSize: 10
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    Icon { icon: "\ue5cc"; font.pixelSize: 18; color: Theme.accent }
                }

                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        try { appRow.modelData.execute(); } catch (e) {}
                        root.launched();
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.query.trim().length > 0 ? "Press a result to launch it." : "Quick search over desktop entries available on this system."
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: 10
        }
    }
}
