#!/usr/bin/env python3
"""Offline RAGE contracts and compositor safety. No real IPC/config changes."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import shutil
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('rage', ROOT / 'scripts/rusticq-glass.py')
RAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RAGE)


class GlassBackendTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('lua'), 'Optional Lua interpreter unavailable')
    def test_settings_rules_are_valid_lua_with_utf8_window_titles(self):
        request=self.request(settingsPresentation=True,settingsBlur=True,hyprSettingsBlur=False,
                             surfaceBlurFlags={'dock':True,'dialogs':False})
        expression=RAGE.settings_program(RAGE.program(True,request['owner']),request)
        # Execute only against local stubs, never a compositor. This verifies
        # syntax and the exact decoded match string, including the middle dot.
        stub='''local rules={}
hl={window_rule=function(r) rules[r.name]=r end,layer_rule=function(r) rules[r.name]=r end}
'''
        checks='''
assert(rules["rusticq-design-settings"].match.title=="^RusticQ · Settings$")
assert(rules["rusticq-design-settings"].no_blur==false)
assert(rules["rusticq-design-hyprsettings"].no_blur==true)
assert(rules["rusticq-surface-dock"].blur==true)
'''
        result=subprocess.run(['lua','-'],input=stub+expression+checks,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_settings_blur_is_independent_of_global_material_toggle(self):
        result=RAGE.apply(self.request(enabled=False,settingsPresentation=True,settingsBlur=True,hyprSettingsBlur=False,settingsRadius=16,hyprSettingsRadius=16))
        self.assertFalse(result['active']);self.assertTrue(result['settingsActive']);self.assertFalse(result['hyprSettingsActive'])
        expression=self.calls[-1][-1]
        self.assertIn('rusticq-design-settings',expression);self.assertIn('rusticq-design-hyprsettings',expression)
        self.assertIn('border_size=0',expression)
        self.assertNotIn('hl.config(',expression)

    def test_settings_and_surface_payloads_are_validated(self):
        for extra in ({'settingsBlur':'true'},{'settingsRadius':900},{'surfaceBlurFlags':{'unexpected':True}},{'surfaceBlurFlags':{'dock':'yes'}}):
            with self.subTest(extra=extra),self.assertRaises(ValueError):RAGE.apply(self.request(**extra))

    def test_settings_blur_needs_global_compositor_blur_and_presentation_rules(self):
        self.global_blur=False
        result=RAGE.apply(self.request(settingsPresentation=True,settingsBlur=True,hyprSettingsBlur=True))
        self.assertFalse(result['settingsActive']);self.assertFalse(result['hyprSettingsActive'])
        self.global_blur=True
        result=RAGE.apply(self.request(settingsBlur=True))
        self.assertFalse(result['settingsActive'])

    def test_surface_rule_override_uses_only_fixed_namespaces(self):
        RAGE.apply(self.request(settingsPresentation=True,surfaceBlurFlags={'dock':False,'widgets':True}))
        expression=self.calls[-1][-1]
        self.assertIn('rusticq-surface-dock',expression)
        self.assertIn('^rusticq-dock$',expression)
        self.assertIn('^rusticq-desktop-widgets$',expression)

    def setUp(self):
        self.calls = []
        self.version = '0.56.2'
        self.global_blur = True
        self.typed_bool = True
        self.errors = ''
        self.answer = 'ok'
        self.backend = patch.object(RAGE, 'backend', return_value='hyprland').start()
        patch.object(RAGE.shutil, 'which', return_value='/usr/bin/hyprctl').start()
        patch.object(RAGE, 'run', side_effect=self.ipc).start()
        self.addCleanup(patch.stopall)

    def ipc(self, args):
        self.calls.append(args)
        if args[-1] == 'version': return json.dumps({'version': self.version})
        if 'getoption' in args: return json.dumps({'bool': self.global_blur} if self.typed_bool else {'int': int(self.global_blur)})
        if 'configerrors' in args: return self.errors
        if args[-1].startswith('assert'): return 'ok'
        return self.answer

    def request(self, **changes):
        return dict(dict(enabled=True, blur=True, performance=False, lowMemory=False,
                         owner='unit-owner'), **changes)

    def test_supported_named_session_rules_and_no_global_mutations(self):
        result = RAGE.apply(self.request())
        self.assertTrue(result['active'])
        self.assertFalse(result['independentStrength'])
        self.assertFalse(result['persistentChanges'])
        script = self.calls[-1][-1]
        self.assertIn('blur_popups=true', script)
        self.assertIn('ignore_alpha=0.02', script)
        self.assertIn('pcall', script)
        self.assertIn('enabled=previous', script)
        for forbidden in ('hl.config', 'reload', 'sudo', 'keyword', 'decoration', 'os.execute'):
            self.assertNotIn(forbidden, script)
        self.assertEqual(sum('configerrors' in c for c in self.calls), 1)

    def test_both_typed_bool_and_legacy_int_options(self):
        for typed in (True, False):
            self.typed_bool = typed
            for enabled in (True, False):
                self.global_blur = enabled
                self.assertEqual(RAGE.capabilities()['globalBlur'], enabled)

    def test_exact_surface_and_window_matching(self):
        for namespace in RAGE.LAYER_NAMES:
            self.assertRegex('rusticq-' + namespace, RAGE.NAMESPACE)
        for other in ('omarchy-bar', 'waybar', 'rusticq-authentication', 'rusticq-keep-awake',
                      'rusticq-recording', 'rusticq-bar-other'):
            self.assertIsNone(re.match(RAGE.NAMESPACE, other))
        self.assertRegex('RusticQ · Settings', RAGE.TITLES)
        self.assertIsNone(re.match(RAGE.TITLES, 'Other application'))
        self.assertIsNone(re.match(RAGE.TITLES, 'RusticQ · Settings evil'))

    def test_disabled_global_blur_is_never_enabled(self):
        self.global_blur = False
        result = RAGE.apply(self.request())
        self.assertTrue(result['supported'])
        self.assertFalse(result['active'])
        self.assertIn('leaves it off', result['message'])
        self.assertFalse(any('hl.config' in c[-1] for c in self.calls))

    def test_naked_or_solid_bar_keeps_popup_and_other_panel_blur(self):
        result = RAGE.apply(dict(self.request(), barBlur=False))
        script = self.calls[-1][-1]
        self.assertTrue(result['active'])
        self.assertIn('name="rusticq-rage-bar"', script)
        self.assertIn('match={namespace="^rusticq-bar$"}, blur=false, blur_popups=true', script)
        self.assertIn('blur=previous_bar', script)
        self.assertIn('quick-control', script)

    def test_bar_request_type_is_strict(self):
        with self.assertRaises(ValueError):
            RAGE.apply(dict(self.request(), barBlur='false'))

    def test_launcher_backdrop_is_independent_and_exactly_scoped(self):
        result = RAGE.apply(dict(self.request(), enabled=False, blur=False,
                                 launcherBlur=False, launcherBackdropBlur=True))
        self.assertFalse(result['active'])
        self.assertFalse(result['launcherActive'])
        self.assertTrue(result['backdropActive'])
        script = self.calls[-1][-1]
        self.assertIn('namespace="^rusticq-launcher-backdrop$"', script)
        self.assertIn('ignore_alpha=0', script)
        self.assertNotIn('hl.config', script)
        for key in ('launcherBlur', 'launcherBackdropBlur'):
            with self.assertRaises(ValueError):
                RAGE.apply(dict(self.request(), **{key:'true'}))

    def test_launcher_none_naked_and_performance_preserve_unrelated_blur(self):
        result = RAGE.apply(dict(self.request(), launcherBlur=False, launcherBackdropBlur=False))
        self.assertTrue(result['active'])
        self.assertFalse(result['launcherActive'])
        self.assertFalse(result['backdropActive'])
        self.assertIn('quick-control', self.calls[-1][-1])
        for key in ('performance', 'lowMemory'):
            result = RAGE.apply(dict(self.request(), launcherBackdropBlur=True, **{key:True}))
            self.assertFalse(result['backdropActive'])
        self.global_blur=False
        result=RAGE.apply(dict(self.request(), launcherBackdropBlur=True))
        self.assertFalse(result['backdropActive'])

    def test_launcher_none_has_no_fullscreen_carrier(self):
        source=(ROOT/'modules/main/LauncherOverlay.qml').read_text()
        self.assertIn('active:overlay.presented && overlay.backdropMode!=="none"', source)
        self.assertIn('mask:Region {item:Store.launcherVisible ? dismissArea : null}',source)
        self.assertIn('color:"transparent"', source)
        self.assertNotIn('Qt.alpha(Theme.background, 0.58)', source)
        self.assertIn('mask:Region', source)
        self.assertIn('launcherSurface.inputItem', source)
        self.assertIn('launcherSurface.resultsItem', source)

    def test_launcher_motion_has_one_owner_even_when_glass_is_disabled(self):
        script=RAGE.program(False,'studio-owner')
        self.assertIn('name="rusticq-launcher-presentation",enabled=true',script)
        self.assertIn('namespace="^rusticq-(launcher(-backdrop)?|dock)$"',script)
        self.assertIn('no_anim=true',script)
        cleanup=RAGE.program(False,'studio-owner',cleanup=True)
        self.assertIn('name="rusticq-launcher-presentation",enabled=false',cleanup)
        self.assertIn('enabled=previous_presentation',cleanup)
        self.assertIn('_G.__rusticq_rage_owner == "studio-owner"',cleanup)

    def test_toggle_blur_performance_and_low_memory_disable_only_owned_rules(self):
        for key in ('enabled', 'blur', 'performance', 'lowMemory'):
            request = self.request()
            request[key] = key in ('performance', 'lowMemory')
            result = RAGE.apply(request)
            self.assertFalse(result['active'])
            script = self.calls[-1][-1]
            self.assertIn('name="rusticq-rage-layers", enabled=false', script)
            self.assertIn('name="rusticq-rage-windows", enabled=false', script)
            self.assertIn('if false or _G.__rusticq_rage_launcher_created then', script)
            self.assertIn('name="rusticq-rage-launcher",enabled=false', script)
            self.assertIn('name="rusticq-rage-launcher-backdrop",enabled=false', script)
            self.assertNotIn('hl.config', script)

    def test_reload_cleanup_is_guarded_by_generation_owner(self):
        script = RAGE.program(False, 'previous-generation', cleanup=True)
        self.assertIn('_G.__rusticq_rage_owner == "previous-generation"', script)
        self.assertIn('_G.__rusticq_rage_owner="new-generation"', RAGE.program(True, 'new-generation'))
        normal_disable = RAGE.program(False, 'new-generation', cleanup=False)
        self.assertNotIn('== "new-generation"', normal_disable)

    def test_legacy_and_future_versions_do_not_generate_unsafe_rules(self):
        for version in ('0.54.3', '0.49.0', '0.58.0', '1.0.0', 'not a version'):
            self.version = version
            self.calls.clear()
            result = RAGE.apply(self.request())
            self.assertFalse(result['supported'], version)
            self.assertFalse(result['active'])
            self.assertFalse(any('eval' in c for c in self.calls))

    def test_unknown_niri_and_ambiguous_use_readable_fallback(self):
        for backend in ('unknown', 'niri', 'ambiguous'):
            self.backend.return_value = backend
            result = RAGE.apply(self.request())
            self.assertFalse(result['supported'])
            self.assertFalse(result['active'])
            self.assertFalse(result['independentStrength'])

    def test_ipc_failure_and_existing_config_errors_do_not_apply(self):
        self.errors = 'An existing unrelated config error'
        result = RAGE.apply(self.request())
        self.assertFalse(result['active'])
        self.assertIn('Existing compositor config errors', result['message'])
        self.assertFalse(any('name="rusticq-rage' in c[-1] for c in self.calls))
        with patch.object(RAGE, 'run', side_effect=subprocess.TimeoutExpired('hyprctl', 5)):
            self.assertFalse(RAGE.capabilities()['supported'])

    def test_invalid_json_values_and_injection_are_rejected_before_ipc(self):
        for data in ([], None, {}, {'enabled': 'true'}, self.request() | {'owner': '"; os.execute("bad")'},
                     self.request() | {'enabled': 1}, self.request() | {'arbitrary': True}):
            self.calls.clear()
            with self.assertRaises(ValueError): RAGE.apply(data)
            self.assertEqual(self.calls, [])

    def test_eval_failure_reports_fallback(self):
        self.answer = 'Lua error: invalid rule'
        result = RAGE.apply(self.request())
        self.assertFalse(result['ok'])
        self.assertFalse(result['active'])


class GlassSourceTests(unittest.TestCase):
    def test_schema_defaults_are_disabled_and_documented(self):
        data = json.loads((ROOT / 'user-settings.example.json').read_text())
        expected = dict(glassmorphismEnabled=False, rageMode='adaptive', ragePalette='obsidian', glassStyle='frosted', glassOpacity=0.44,
                        glassBlurEnabled=True, glassBlurRadius=24, glassBorderOpacity=0.16,
                        glassCornerRadius=20, glassReflectionEnabled=True, glassShadowEnabled=True,
                        glassShadowIntensity=0.14, glassTintStrength=0.10, glassPerformanceMode=False)
        store = (ROOT / 'config/SettingsStore.qml').read_text()
        for key, value in expected.items():
            self.assertEqual(data[key], value, key)
            self.assertIn(key + ': ' + key, store)
        self.assertIn('applyGlassSettings(data)', store)
        self.assertIn('changed.every(key => Object.prototype.hasOwnProperty.call(root.glassDefaults, key)', store)
        self.assertIn('Object.prototype.hasOwnProperty.call(root.barSurfaceDefaults,key)', store)

    def test_base_palette_and_aether_are_preserved(self):
        theme = (ROOT / 'config/Theme.qml').read_text()
        self.assertIn('background: Qt.alpha(effectivePalette.background, 1)', theme)
        self.assertIn('if (rageExclusive) return ragePalettes[SettingsStore.ragePalette]', theme)
        self.assertIn('surface:"#3c3836"', theme)
        self.assertIn('/.config/aether/theme/colors.toml', theme)
        self.assertIn('onFileChanged: aetherFile.reload()', theme)
        for role in ('glassWindow', 'glassPrimary', 'glassSecondary', 'glassCard', 'glassControl',
                     'glassHover', 'glassPressed', 'glassSelected', 'glassPopup', 'glassTooltip',
                     'glassBorderColor', 'glassSpecular', 'glassShadowColor', 'glassModal', 'glassAuthentication'):
            self.assertIn('property color ' + role + ':', theme)

    def test_active_components_do_not_bypass_the_palette_resolver(self):
        # The appearance editor's literal accent swatches are a catalog, hidden
        # in Exclusive. Native surfaces must not consume those values directly.
        for directory in ('components', 'modules'):
            for path in (ROOT/directory).rglob('*.qml'):
                source = path.read_text()
                self.assertNotIn('Theme.aetherPalette', source, str(path))
                self.assertNotIn('SettingsStore.accentColor', source, str(path))
                if path.name != 'SettingsAppearancePage.qml':
                    self.assertIsNone(re.search(r'#[bB]8[bB][bB]26|#[dD]65[dD]0[eE]|#[eE][bB][dD][bB][bB]2|#282828|#3[cC]3836', source), str(path))
        appearance = (ROOT/'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        self.assertIn('visible: !Theme.rageExclusive && SettingsStore.colorSource === "gruvbox"', appearance)

    def test_no_framebuffer_capture_or_shader_dependency(self):
        for name in ('GlassSurface', 'GlassHighlight', 'GlassPreview'):
            source = (ROOT / 'components' / (name + '.qml')).read_text()
            for forbidden in ('ShaderEffectSource {', 'MultiEffect {', 'layer.enabled: true', 'Timer {'):
                self.assertNotIn(forbidden, source)
        self.assertIn('active: root.visible', (ROOT / 'components/GlassSurface.qml').read_text())

    def test_lock_background_and_auth_controller_remain_secure(self):
        surface = (ROOT / 'modules/lock/RusticQLockSurface.qml').read_text()
        controller = (ROOT / 'lockscreen.qml').read_text()
        self.assertIn('color: Theme.background', surface)
        self.assertIn('Rectangle { anchors.fill: parent; color: Theme.background }', surface)
        self.assertIn('Theme.glassColor("authentication", Theme.background)', surface)
        self.assertNotIn('glassColor("window"', surface)
        self.assertNotIn('sessionLock.locked = false', surface)
        self.assertIn('if (result === PamResult.Success && sessionLock.secure)', controller)
        self.assertEqual(controller.count('sessionLock.locked = false;'), 1)

    def test_namespace_surface_types(self):
        popup = (ROOT / 'modules/main/IndicatorPopup.qml').read_text()
        self.assertIn('PanelWindow {', popup)
        self.assertIn('WlrLayershell.namespace: "rusticq-popups"', popup)
        for name in ('SettingsWindow', 'DeviceSettingsWindow'):
            source = (ROOT / 'modules/settings' / (name + '.qml')).read_text()
            self.assertNotIn('WlrLayershell.namespace', source)
        for name in ('Bar', 'RusticDock', 'LauncherOverlay', 'NotificationToasts', 'DesktopWidgetWindow', 'SystemOsd'):
            source = (ROOT / 'modules/main' / (name + '.qml')).read_text()
            self.assertIn('WlrLayershell.namespace: "rusticq-', source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
