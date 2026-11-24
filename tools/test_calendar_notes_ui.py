#!/usr/bin/env python3
"""Calendar note editing, shared markers and persistence in isolated Quickshell."""
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "modules/main"
ShellRoot {
    Window {
        visible: true
        width: 780; height: 800
        color: Theme.background
        Rectangle {
            id: firstPreview
            x: 8; y: 8; width: 352; height: first.height
            color: Theme.background
            radius: Theme.sectionRadius
            MiniDate { id: first; width: parent.width; height: implicitHeight }
        }
        MiniDate { id: second; x: 400; y: 8; width: 352; height: implicitHeight }
        TestCase {
            name: "CalendarNotes"
            when: true
            property bool captured: false
            function childrenOf(item) {
                let found = [item];
                for (const child of item.children) found = found.concat(childrenOf(child));
                return found;
            }
            function control(name, view) {
                const item = childrenOf(view || first).find(child => child.objectName === name);
                verify(item !== undefined, name);
                return item;
            }
            function click(name, view) {
                const item = control(name, view);
                mouseClick(item, item.width / 2, item.height / 2);
                wait(30);
            }
            function input(name, text) {
                const item = control(name);
                item.forceActiveFocus();
                item.selectAll();
                keyClick(Qt.Key_Backspace);
                item.insert(0, text);
                wait(20);
            }
            function capture(name) {
                captured = false;
                firstPreview.grabToImage(function(result) {
                    captured = result.saveToFile("/tmp/rusticq-calendar-" + name + ".png");
                });
                tryVerify(() => captured, 1500);
            }
            function init() {
                SettingsStore.calendarNotes = ({});
                first.height = Qt.binding(() => first.implicitHeight);
                first.selectDate(new Date(2026, 10, 13));
                second.selectDate(new Date(2026, 10, 13));
                wait(30);
            }
            function cleanup() { console.log("CALENDAR TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
            function cleanupTestCase() { console.log("CALENDAR RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            function test_compact_add_edit_and_shared_markers() {
                const add = control("calendar-edit");
                compare(add.label, "Add activity");
                verify(add.width < first.width / 2);
                click("calendar-edit");
                verify(first.editing);
                verify(!control("calendar-save").enabled);
                input("calendar-note-title", "Team meeting");
                input("calendar-note-details", "Bring notes\\nRoom 4");
                click("calendar-category-work");
                click("calendar-save");
                verify(!first.editing);
                compare(SettingsStore.calendarNote("2026-11-13").title, "Team meeting");
                compare(SettingsStore.calendarNote("2026-11-13").category, "work");
                compare(second.selectedNote.notes, "Bring notes\\nRoom 4");
                verify(control("calendar-marker-2026-11-13").visible);
                verify(control("calendar-marker-2026-11-13", second).visible);
                compare(control("calendar-activity-edit").label, "Edit");
                click("calendar-activity-edit", second);
                second.draftTitle = "Changed elsewhere";
                second.saveNote();
                compare(first.selectedNote.title, "Changed elsewhere");
            }
            function test_cancel_delete_and_empty_title() {
                verify(SettingsStore.setCalendarNote(first.selectedKey, "Birthday", "birthday", "Cake"));
                click("calendar-activity-edit");
                input("calendar-note-title", "Unsaved edit");
                click("calendar-cancel");
                compare(first.selectedNote.title, "Birthday");
                click("calendar-delete");
                compare(first.selectedNote, null);
                compare(second.selectedNote, null);
                verify(!control("calendar-marker-2026-11-13").visible);
                click("calendar-edit");
                input("calendar-note-title", "   ");
                verify(!control("calendar-save").enabled);
                click("calendar-cancel");
            }
            function test_calendar_navigation_and_leap_dates() {
                first.selectDate(new Date(2028, 0, 31));
                click("calendar-next");
                compare(first.selectedKey, "2028-02-29");
                click("calendar-prev");
                compare(first.selectedDate.getMonth(), 0);
                click("calendar-day-2028-01-01");
                compare(first.selectedKey, "2028-01-01");
                click("calendar-today");
                compare(first.selectedKey, SettingsStore.calendarDateKey(new Date()));
                compare(SettingsStore.calendarDateKey(new Date(2026, 0, 1, 0, 10)), "2026-01-01");
            }
            function test_validation_and_safe_import_defaults() {
                for (const date of ["2026-02-30", "2026-13-01", "2026-00-01", "26-01-01", "__proto__", "2026-11-00"]) {
                    verify(!SettingsStore.setCalendarNote(date, "Invalid", "event", ""));
                }
                verify(!SettingsStore.setCalendarNote("2026-11-13", "", "event", ""));
                verify(!SettingsStore.setCalendarNote("2026-11-13", "x".repeat(121), "event", ""));
                verify(!SettingsStore.setCalendarNote("2026-11-13", "Title", "unknown", ""));
                verify(!SettingsStore.setCalendarNote("2026-11-13", "Title", "event", "x".repeat(1001)));
                verify(!SettingsStore.setCalendarNote("2026-11-13", "Line\\nBreak", "event", ""));
                const clean = SettingsStore.normalizeCalendarNotes({
                    "2026-02-30": {title: "Bad date"},
                    "2028-02-29": {title: " Leap day ", category: "unknown", notes: "x".repeat(1100)},
                    "2026-11-13": {title: 17}, "2026-01-01": {title: ""}
                });
                compare(Object.keys(clean).length, 1);
                compare(clean["2028-02-29"].title, "Leap day");
                compare(clean["2028-02-29"].category, "event");
                compare(clean["2028-02-29"].notes.length, 1000);
            }
            function test_editor_scrolls_on_short_screens() {
                click("calendar-edit");
                first.height = 260;
                wait(30);
                const viewport = control("calendar-viewport");
                verify(viewport.contentHeight > viewport.height);
                viewport.contentY = viewport.contentHeight - viewport.height;
                wait(30);
                const save = control("calendar-save");
                const point = save.mapToItem(viewport, 0, 0);
                verify(point.y >= 0 && point.y + save.height <= viewport.height + 1);
            }
            function test_z_save_and_preview() {
                capture("empty");
                click("calendar-edit");
                input("calendar-note-title", "Birthday <b>literal</b>");
                input("calendar-note-details", "Dinner at home");
                click("calendar-category-birthday");
                capture("editor");
                click("calendar-save");
                wait(100);
                capture("agenda");
                verify(childrenOf(first).some(child => child.text === "Birthday <b>literal</b>" && child.textFormat === Text.PlainText));
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-calendar-notes-') as folder:
        root = Path(folder)
        for name in ('config', 'components', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        original = {'showWifi': True, 'clockFormat': 'HH:mm:ss'}
        (root / 'user-settings.json').write_text(json.dumps(original))
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        output = run_qml(root, env, QML)
        result = re.search(r'CALENDAR RESULTS (\d+) passed, (\d+) failed', output)
        assert result and int(result[1]) >= 6 and int(result[2]) == 0, output
        saved = json.loads((root / 'user-settings.json').read_text())
        for key, value in original.items():
            assert saved[key] == value, key
        note = {'title': 'Birthday <b>literal</b>', 'category': 'birthday', 'notes': 'Dinner at home'}
        assert saved['calendarNotes'] == {'2026-11-13': note}, saved['calendarNotes']
        reload_source = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {
    TestCase {
        when: true
        function test_reload() {
            compare(SettingsStore.calendarNote("2026-11-13").title, "Birthday <b>literal</b>");
            compare(SettingsStore.calendarNote("2026-11-13").category, "birthday");
            compare(SettingsStore.calendarNote("2026-11-13").notes, "Dinner at home");
            console.log("CALENDAR RELOAD PASS");
        }
    }
}
'''
        assert 'CALENDAR RELOAD PASS' in run_qml(root, env, reload_source)
    print('PASS: compact Add/Edit, categories, notes, shared date markers, delete/cancel, validation, navigation, scrolling and save/reload')


if __name__ == '__main__':
    main()
