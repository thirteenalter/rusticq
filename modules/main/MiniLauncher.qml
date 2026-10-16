import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../../config"
import "../../components"

Rectangle {
    id: root
    signal launched()
    radius: Theme.sectionRadius
    color: Qt.alpha(Theme.foreground, 0.03)
    border.width: 0
    border.color: "transparent"
    property string query: ""
    property var results: []
    property var frequent: []
    property bool showAll: false
    function launch(entry) {
        try {
            entry.execute();
            AppUsage.noteLaunch(entry);
            launched();
        } catch (e) { console.warn("Launcher failed to start " + textOf(entry.name) + ": " + e); }
    }

    function rebuild() {
        const entries = DesktopEntries.applications.values;
        const found = [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (entry && matches(entry)) found.push(entry);
        }
        found.sort((a, b) => {
            const sa = AppUsage.stats(a), sb = AppUsage.stats(b);
            if (sa.pinned !== sb.pinned) return sa.pinned ? -1 : 1;
            if (sa.count !== sb.count) return sb.count - sa.count;
            if (sa.last !== sb.last) return sb.last - sa.last;
            return textOf(a.name).localeCompare(textOf(b.name));
        });
        frequent = found.filter(e => {
            const st = AppUsage.stats(e);
            return st.pinned || st.count > 0;
        }).slice(0, 6);
        results = found;
    }
    onQueryChanged: rebuild()
    Connections {
        target: AppUsage
        function onUsageChanged() { root.rebuild(); }
    }
    Component.onCompleted: rebuild()
    onVisibleChanged: if (visible) Qt.callLater(function() { rebuild(); searchField.forceActiveFocus(); })
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuild(); }
    }

    function iconSource(entry) {
        const icon = textOf(entry.icon);
        return icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true);
    }
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
                text: DesktopEntries.applications.values.length + " apps"
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
                    Component.onCompleted: Qt.callLater(function() { forceActiveFocus(); })
                    Keys.onEscapePressed: Store.launcherVisible = false
                    Text {
                        visible: searchField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type to search apps"
                        color: Theme.muted
                        font.family: Fonts.poppins.name
                        font.pixelSize: 11
                    }
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

        ColumnLayout {
            visible: root.query.trim() === "" && root.frequent.length > 0
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "\ue838"; font.pixelSize: 17; color: Theme.accent }
                Text { text: "Pinned & frequently used"; font.family: Fonts.poppinsSB.name; color: Theme.foreground; font.pixelSize: 11; Layout.fillWidth: true }
                Text { text: root.frequent.length + " apps"; color: Theme.muted; font.pixelSize: 10 }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: root.frequent
                    delegate: Rectangle {
                        id: frequentApp
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 11
                        color: favMouse.containsMouse ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 7
                            IconImage {
                                Layout.preferredWidth: 25; Layout.preferredHeight: 25
                                source: root.iconSource(frequentApp.modelData)
                                visible: String(source).length > 0
                            }
                            Text { text: root.textOf(frequentApp.modelData.name); Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                        }
                        MouseArea { id: favMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(frequentApp.modelData) }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: root.query.trim() === "" ? "All applications" : "Search results"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: root.results.length + " found"; color: Theme.muted; font.pixelSize: 10 }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: appRow
                required property var modelData
                width: ListView.view.width
                height: 56
                radius: 12
                color: appMouse.containsMouse ? Qt.alpha(Theme.accent, 0.12) : Theme.surface
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: Qt.alpha(Theme.accent, 0.11)
                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 30; height: 30
                            source: root.iconSource(appRow.modelData)
                            visible: String(source).length > 0
                        }
                        Text {
                            visible: !appIcon.visible
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
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        color: pinMouse.containsMouse ? Qt.alpha(Theme.accent, 0.15) : "transparent"
                        Icon { anchors.centerIn: parent; icon: AppUsage.stats(appRow.modelData).pinned ? "\ue838" : "\ue83a"; font.pixelSize: 18; color: Theme.accent }
                        MouseArea {
                            z: 3
                            id: pinMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AppUsage.togglePinned(appRow.modelData)
                        }
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: 43
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(appRow.modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.results.length === 0 ? "No matching applications" : root.query.trim().length > 0 ? root.results.length + " matching apps · choose to launch" : "Installed applications · choose to launch"
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.family: Fonts.poppins.name
            font.pixelSize: 10
        }
    }
}
