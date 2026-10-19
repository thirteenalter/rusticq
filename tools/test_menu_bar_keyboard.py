#!/usr/bin/env python3
"""Offline keyboard menu navigation regression. Does not dispatch any actions."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
MENU = (ROOT / 'modules/main/ContextMenu.qml').read_text()
POPUP = (ROOT / 'modules/main/IndicatorPopup.qml').read_text()
BAR = (ROOT / 'modules/main/Bar.qml').read_text()


def function_source(name):
    match = re.search(r'\bfunction\s+' + re.escape(name) + r'\s*\([^)]*\)\s*\{', MENU)
    if not match:
        raise AssertionError(f'QML function {name} missing')
    # Select exactly one function, including nested JS blocks.
    open_brace = match.end() - 1
    depth = 0
    for pos in range(open_brace, len(MENU)):
        if MENU[pos] == '{':
            depth += 1
        elif MENU[pos] == '}':
            depth -= 1
            if not depth:
                return MENU[match.start():pos+1]
    raise AssertionError(f'Unterminated QML function {name}')


class KeyboardMenuTests(unittest.TestCase):
    def test_popup_keyboard_focus_is_gated_by_menu_kind(self):
        self.assertIn('grabFocus: true', POPUP)
        self.assertIn('kind === "menu"', POPUP)
        self.assertIn('widgetLoader.item.forceActiveFocus()', POPUP)
        self.assertIn('onLoaded: if (popup.kind === "menu")', POPUP)
        self.assertIn('FocusScope {', MENU)
        self.assertIn('Keys.onPressed:', MENU)
        self.assertIn('root.forceActiveFocus()', MENU)
        self.assertNotIn('Keys.onPressed:', BAR)

    def test_arrow_enter_escape_are_handled_locally(self):
        for name in ('Left', 'Right', 'Up', 'Down', 'Return', 'Enter', 'Escape'):
            self.assertIn('Qt.Key_' + name, MENU)
        self.assertIn('Qt.Key_Space', MENU)
        self.assertIn('event.accepted = true', MENU)
        self.assertIn('activateSelection()', MENU)
        self.assertIn('actionFinished(); event.accepted = true;', MENU)

    def test_mouse_and_keyboard_keep_the_same_highlight(self):
        self.assertIn('readonly property bool selected: root.selectedIndex === index', MENU)
        self.assertIn('selected || choiceMouse.containsMouse', MENU)
        self.assertIn('onEntered: root.selectedIndex = choice.index', MENU)
        self.assertIn('function ensureSelectedVisible()', MENU)
        self.assertIn('entryList.contentY =', MENU)

    def test_tabs_keep_popup_section_and_height_synchronized(self):
        self.assertIn('signal sectionNavigated(string sectionKey)', MENU)
        self.assertIn('sectionNavigated(key);', MENU)
        self.assertIn('onSectionNavigated: function(sectionKey)', POPUP)
        self.assertIn('signal menuSectionNavigated(string sectionKey)', POPUP)
        self.assertIn('onMenuSectionNavigated: function(sectionKey)', BAR)
        self.assertIn('barWindow.menuSection = sectionKey', BAR)
        self.assertIn('menuSection === "share" ? 530 : 345', POPUP)
        self.assertIn('selectedIndex = 0;', MENU)

    @unittest.skipUnless(shutil.which('node'), 'JavaScript runtime not installed')
    def test_real_qml_functions_work_in_javascript(self):
        helpers = '\n'.join(function_source(n) for n in (
            'selectSection', 'switchSection', 'moveSelection', 'activateSelection'))
        script = r'''"use strict";
let sections = [{key:"edit"}, {key:"view"}, {key:"share"}, {key:"shell"}];
let currentSection = "edit";
let entries = [{action:"terminal"},{action:"monitor"},{action:"power"}];
let selectedIndex = 0;
let navigation = [];
let actions = [];
function sectionNavigated(k) { navigation.push(k); }
function runAction(k) { actions.push(k); }
''' + helpers + r'''
function check(value, msg) { if (!value) throw Error(msg); }
switchSection(-1); check(currentSection === "shell", "Left must wrap to Shell");
switchSection(1); check(currentSection === "edit", "Right must wrap to Edit");
switchSection(1); check(currentSection === "view", "Right moves one enabled section");
check(navigation.join(",") === "shell,edit,view", "Popup section must be notified");
selectSection("disabled"); check(currentSection === "view", "Ignore disabled tab");
moveSelection(-1); check(selectedIndex === 2, "Up wraps to last action");
activateSelection(); check(actions[0] === "power", "Enter activates selected row");
moveSelection(1); check(selectedIndex === 0, "Down wraps to first action");
activateSelection(); check(actions[1] === "terminal", "First action must execute");
check(actions.length === 2, "Arrow keys must not execute actions");
console.log("Keyboard menu JS: wrap, disabled sections, selection and activation OK");
'''
        process = subprocess.run(['node', '-e', script], capture_output=True, text=True, timeout=10)
        self.assertEqual(process.returncode, 0, process.stderr)


if __name__ == '__main__':
    unittest.main()
