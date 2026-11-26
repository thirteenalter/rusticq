import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../config"
import "../../components"

Item {
    id: root
    objectName: "calendar-popup-widget"
    implicitHeight: content.implicitHeight + Theme.sectionPadding * 2
    property date selectedDate: new Date()
    property date displayedMonth: new Date()
    property bool editing: false
    property string draftTitle: ""
    property string draftCategory: "event"
    property string draftNotes: ""
    property string message: ""
    readonly property string selectedKey: SettingsStore.calendarDateKey(selectedDate)
    readonly property var selectedNote: SettingsStore.calendarNote(selectedKey)
    readonly property var weekdays: ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
    SystemClock { id: dateClock; precision: SystemClock.Minutes }

    function dayAt(index) {
        const first = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1);
        return new Date(first.getFullYear(), first.getMonth(), index - (first.getDay() + 6) % 7 + 1);
    }
    function selectDate(date) {
        selectedDate = date;
        displayedMonth = new Date(date.getFullYear(), date.getMonth(), 1);
        editing = false;
        message = "";
        viewport.contentY = 0;
    }
    function moveMonth(delta) {
        const month = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + delta, 1);
        const day = Math.min(selectedDate.getDate(), new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate());
        selectDate(new Date(month.getFullYear(), month.getMonth(), day));
    }
    function beginEdit() {
        draftTitle = selectedNote ? selectedNote.title : "";
        draftCategory = selectedNote ? selectedNote.category : "event";
        draftNotes = selectedNote ? selectedNote.notes : "";
        message = "";
        editing = true;
        viewport.contentY = 0;
        Qt.callLater(function() { titleInput.forceActiveFocus(); });
    }
    function saveNote() {
        if (!SettingsStore.setCalendarNote(selectedKey, draftTitle, draftCategory, draftNotes)) {
            message = "Unable to save. Check the activity title and details.";
            return;
        }
        editing = false;
        message = "Activity saved.";
    }

    Flickable {
        id: viewport
        objectName: "calendar-viewport"
        anchors.fill: parent
        contentHeight: content.implicitHeight + Theme.sectionPadding * 2
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollIndicator.vertical: ScrollIndicator {}
        ColumnLayout {
            id: content
            objectName: "surfaceContent"
            x: Theme.sectionPadding
            y: Theme.sectionPadding
            width: Math.max(0, viewport.width - Theme.sectionPadding * 2)
            spacing: Theme.contentGap
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { icon: "\uebcc"; font.pixelSize: Fonts.scale(20); color: Theme.accent }
                GlassLabel {
                    text: root.editing ? (root.selectedNote ? "Edit activity" : "Add activity") : "Calendar"
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(16)
                    color: Theme.foreground
                    Layout.fillWidth: true
                }
                ActionButton {
                    objectName: "calendar-editor-back"
                    visible: root.editing
                    symbol: "\ue5c4"
                    label: "Back"
                    onClicked: { root.editing = false; root.message = ""; }
                }
                ActionButton {
                    objectName: "calendar-prev"
                    visible: !root.editing
                    symbol: "\ue5cb"
                    Accessible.name: "Previous month"
                    onClicked: root.moveMonth(-1)
                }
                ActionButton {
                    objectName: "calendar-next"
                    visible: !root.editing
                    symbol: "\ue5cc"
                    Accessible.name: "Next month"
                    onClicked: root.moveMonth(1)
                }
            }
            RowLayout {
                visible: !root.editing
                Layout.fillWidth: true
                GlassLabel {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.displayedMonth, "MMMM yyyy")
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(17)
                    color: Theme.foreground
                }
                ActionButton {
                    objectName: "calendar-today"
                    label: "Today"
                    onClicked: root.selectDate(dateClock.date)
                }
            }
            GridLayout {
                visible: !root.editing
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 3
                rowSpacing: 4
                Repeater {
                    model: root.weekdays
                    delegate: GlassLabel {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.contentMuted
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(10)
                    }
                }
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        id: dateCell
                        required property int index
                        readonly property date cellDate: root.dayAt(index)
                        readonly property string dateKey: SettingsStore.calendarDateKey(cellDate)
                        readonly property var note: SettingsStore.calendarNote(dateKey)
                        readonly property bool currentMonth: cellDate.getMonth() === root.displayedMonth.getMonth()
                        readonly property bool isToday: cellDate.toDateString() === dateClock.date.toDateString()
                        readonly property bool selected: dateKey === root.selectedKey
                        objectName: "calendar-day-" + dateKey
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.glassRadius("card", Theme.rowRadius)
                        color: Theme.glassColor("card", isToday ? Theme.accent : selected ? Qt.alpha(Theme.accent, 0.18) : pointer.containsMouse ? Theme.surface : "transparent")
                        activeFocusOnTab: true
                        border.width: Theme.glassBorderWidth("card", activeFocus ? 1 : 0)
                        border.color: Theme.glassBorder("card", Theme.accent)
                        Accessible.role: Accessible.Button
                        Accessible.name: Qt.formatDate(cellDate, "dddd, dd MMMM yyyy") + (note ? " · " + note.title : "")
                        Accessible.onPressAction: root.selectDate(cellDate)
                        Keys.onReturnPressed: root.selectDate(cellDate)
                        Keys.onSpacePressed: root.selectDate(cellDate)
                        GlassLabel {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: dateCell.note ? -2 : 0
                            text: dateCell.cellDate.getDate()
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(11)
                            color: dateCell.isToday ? Theme.background : dateCell.currentMonth ? Theme.foreground : Theme.muted
                        }
                        Rectangle {
                            objectName: "calendar-marker-" + dateCell.dateKey
                            visible: dateCell.note !== null
                            width: 4
                            height: 4
                            radius: 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: dateCell.isToday ? Theme.background : Theme.calendarCategoryColor(dateCell.note ? dateCell.note.category : "event")
                        }
                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectDate(dateCell.cellDate)
                        }
                    }
                }
            }
            ColumnLayout {
                visible: !root.editing
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 48
                        radius: Theme.glassRadius("card", Theme.rowRadius)
                        color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.10))
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            GlassLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.selectedDate, "dd")
                                color: Theme.accent
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(19)
                            }
                            GlassLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.selectedDate, "MMM").toUpperCase()
                                color: Theme.contentMuted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(8)
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        GlassLabel {
                            Layout.fillWidth: true
                            text: Qt.formatDate(root.selectedDate, "dddd")
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(13)
                            color: Theme.foreground
                            elide: Text.ElideRight
                        }
                        GlassLabel {
                            Layout.fillWidth: true
                            text: root.selectedNote ? "Your activity" : "Nothing planned"
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(10)
                            color: Theme.contentMuted
                        }
                    }
                    ActionButton {
                        objectName: "calendar-edit"
                        visible: root.selectedNote === null
                        label: "Add activity"
                        symbol: "\ue145"
                        selected: true
                        onClicked: root.beginEdit()
                    }
                }
                Rectangle {
                    visible: root.selectedNote !== null
                    Layout.fillWidth: true
                    implicitHeight: activityContent.implicitHeight + 24
                    radius: Theme.glassRadius("card", Theme.rowRadius)
                    color: Theme.glassColor("card", Theme.surface)
                    border.width: Theme.glassBorderWidth("card", 1)
                    border.color: Theme.glassBorder("card", Theme.borderaccent)
                    ColumnLayout {
                        id: activityContent
                        x: 12
                        y: 12
                        width: Math.max(0, parent.width - 24)
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Theme.calendarCategoryColor(root.selectedNote ? root.selectedNote.category : "event")
                            }
                            GlassLabel {
                                Layout.fillWidth: true
                                text: root.selectedNote ? root.selectedNote.category.charAt(0).toUpperCase() + root.selectedNote.category.slice(1) : ""
                                color: Theme.calendarCategoryColor(root.selectedNote ? root.selectedNote.category : "event")
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(10)
                            }
                            ActionButton {
                                objectName: "calendar-activity-edit"
                                label: "Edit"
                                symbol: "\ue3c9"
                                implicitHeight: 30
                                onClicked: root.beginEdit()
                            }
                            ActionButton {
                                objectName: "calendar-delete"
                                symbol: "\ue872"
                                implicitHeight: 30
                                destructive: true
                                Accessible.name: "Delete activity"
                                onClicked: {
                                    SettingsStore.removeCalendarNote(root.selectedKey);
                                    root.message = "Activity removed.";
                                }
                            }
                        }
                        GlassLabel {
                            Layout.fillWidth: true
                            text: root.selectedNote ? root.selectedNote.title : ""
                            textFormat: Text.PlainText
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(14)
                            color: Theme.foreground
                            wrapMode: Text.WordWrap
                        }
                        GlassLabel {
                            visible: !!root.selectedNote && root.selectedNote.notes.length > 0
                            Layout.fillWidth: true
                            text: root.selectedNote ? root.selectedNote.notes : ""
                            textFormat: Text.PlainText
                            color: Theme.contentMuted
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(11)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            ColumnLayout {
                visible: root.editing
                Layout.fillWidth: true
                spacing: Theme.contentGap
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.glassRadius("card", Theme.rowRadius)
                    color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.08))
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Icon { icon: "\uebcc"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                        GlassLabel {
                            Layout.fillWidth: true
                            text: Qt.formatDate(root.selectedDate, "ddd, dd MMMM yyyy")
                            color: Theme.foreground
                            font.family: Fonts.poppins.name
                            font.pixelSize: Fonts.scale(11)
                            elide: Text.ElideRight
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    GlassLabel { text: "Activity"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Theme.glassRadius("card", Theme.rowRadius)
                        color: Theme.glassColor("card", Theme.surface)
                        border.width: Theme.glassBorderWidth("card", 1)
                        border.color: Theme.glassBorder("card", titleInput.activeFocus ? Theme.accent : Theme.borderaccent)
                        TextInput {
                            id: titleInput
                            objectName: "calendar-note-title"
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            text: root.draftTitle
                            onTextEdited: root.draftTitle = text
                            maximumLength: 120
                            color: Theme.foreground
                            font.family: Fonts.poppinsSB.name
                            font.pixelSize: Fonts.scale(13)
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            Accessible.name: "Activity title"
                            Keys.onReturnPressed: if (text.trim()) root.saveNote()
                            GlassLabel {
                                visible: titleInput.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                text: "What’s planned?"
                                color: Theme.contentMuted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(12)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    GlassLabel { text: "Category"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: SettingsStore.calendarCategories
                            delegate: ActionButton {
                                required property string modelData
                                objectName: "calendar-category-" + modelData
                                Layout.fillWidth: true
                                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                selected: root.draftCategory === modelData
                                onClicked: root.draftCategory = modelData
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        GlassLabel { text: "Details"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                        Item { Layout.fillWidth: true }
                        GlassLabel { text: "Optional"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9) }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 90
                        radius: Theme.glassRadius("card", Theme.rowRadius)
                        color: Theme.glassColor("card", Theme.surface)
                        border.width: Theme.glassBorderWidth("card", 1)
                        border.color: Theme.glassBorder("card", notesInput.activeFocus ? Theme.accent : Theme.borderaccent)
                        Flickable {
                            id: notesViewport
                            anchors.fill: parent
                            anchors.margins: 12
                            clip: true
                            contentWidth: width
                            contentHeight: notesInput.height
                            TextEdit {
                                id: notesInput
                                objectName: "calendar-note-details"
                                width: notesViewport.width
                                height: Math.max(notesViewport.height, contentHeight)
                                text: root.draftNotes
                                textFormat: TextEdit.PlainText
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                color: Theme.foreground
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(11)
                                Accessible.name: "Optional activity details"
                                onTextChanged: {
                                    if (text.length > 1000) remove(1000, text.length);
                                    root.draftNotes = text;
                                }
                                onCursorRectangleChanged: {
                                    if (cursorRectangle.y < notesViewport.contentY) notesViewport.contentY = cursorRectangle.y;
                                    else if (cursorRectangle.y + cursorRectangle.height > notesViewport.contentY + notesViewport.height)
                                        notesViewport.contentY = cursorRectangle.y + cursorRectangle.height - notesViewport.height;
                                }
                                GlassLabel {
                                    visible: notesInput.text.length === 0
                                    text: "Add a few details…"
                                    color: Theme.contentMuted
                                    font: notesInput.font
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ActionButton {
                        objectName: "calendar-cancel"
                        label: "Cancel"
                        onClicked: { root.editing = false; root.message = ""; }
                    }
                    ActionButton {
                        objectName: "calendar-save"
                        Layout.fillWidth: true
                        label: "Save activity"
                        symbol: "\ue5ca"
                        selected: true
                        enabled: root.draftTitle.trim().length > 0
                        onClicked: root.saveNote()
                    }
                }
            }
            GlassLabel {
                visible: root.message.length > 0
                text: root.message
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.contentMuted
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(10)
            }
        }
    }
}
