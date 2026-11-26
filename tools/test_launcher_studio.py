#!/usr/bin/env python3
"""Offline Launcher Studio integration contracts; runtime suite is separate."""
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
STYLES=('compact','clean-hover','spotlight','raycast','launchpad','fluent','minimal','classic','overview','command','detached')


def source(path):
    return (ROOT/path).read_text()


class LauncherStudioContracts(unittest.TestCase):
    def test_native_canvas_and_warm_cache_avoid_resize_and_rebuild_per_frame(self):
        dock=source('modules/main/RusticDock.qml')
        self.assertNotIn('Behavior on implicitWidth',dock)
        self.assertNotIn('Behavior on implicitHeight',dock)
        self.assertIn('mask: Region { item: SettingsStore.showDock ? dockSurface : null }',dock)
        self.assertIn('snapshot !== dock.runningSnapshot',dock)
        self.assertIn('target: dockContents',dock)
        self.assertIn('motionCanvasHeight',source('modules/main/LauncherOverlay.qml'))
        shell=source('shell.qml')
        self.assertIn('keepLoaded: warmed && !SettingsStore.lowMemoryShellMode',shell)
        service=source('services/GlassService.qml')
        self.assertIn('root.requestData()',service)
        self.assertNotIn('onLauncherVisibleChanged',service)
        self.assertNotIn('Store.launcherVisible',service)

    def test_single_validated_schema_and_documented_defaults(self):
        store=source('config/SettingsStore.qml')
        defaults=json.loads(re.search(r'launcherAppearanceDefaults: \((\{.*?\})\)',store).group(1))
        example=json.loads(source('user-settings.example.json'))
        enums=json.loads(re.search(r'launcherEnums: \((\{.*?\})\)',store).group(1))
        self.assertEqual(tuple(enums['launcherLayoutMode']),STYLES)
        for key,value in defaults.items():
            self.assertEqual(example[key],value,key)
            self.assertRegex(store,rf'property (?:int|real|bool|string) {key}:')
        self.assertNotRegex(store,r'property string launcherStyle:')
        self.assertIn('launcherSnapshot()',store)
        self.assertIn('root.loadLauncherSettings(data)',store)
        self.assertIn('function resetDetachedLauncherAppearance()',store)
        self.assertIn('key.startsWith("detachedLauncher")',store)

    def test_one_index_editor_and_safe_execution_path(self):
        facade=source('modules/main/MiniLauncher.qml')
        backend=source('components/LauncherController.qml')
        view=source('components/LauncherView.qml')
        self.assertEqual(facade.count('LauncherController {'),1)
        self.assertEqual(view.count('TextInput {'),1)
        self.assertIn('applicationEntries: DesktopEntries.applications.values',backend)
        self.assertIn('entry.execute();',backend)
        self.assertIn('root.toolQuery === response.query',backend)
        self.assertIn('root.query.trim().substring(1) === response.expression',backend)
        for path in ('components/LauncherView.qml','components/LauncherResults.qml','components/LauncherStylePreview.qml'):
            frontend=source(path)
            for forbidden in ('Process {','DesktopEntries.applications','eval(','bash -c','sh -c'):
                self.assertNotIn(forbidden,frontend,path)
        self.assertIn('toolDismissTimer.stop()',backend)
        self.assertIn('root.query===root.actionQuery',backend)

    def test_bounded_transparent_window_and_optional_lower_backdrop(self):
        overlay=source('modules/main/LauncherOverlay.qml')
        self.assertIn('anchors {top:true;left:true}',overlay)
        self.assertIn('color:"transparent"',overlay)
        self.assertIn('LauncherStyle.anchor(',overlay)
        self.assertIn('windows:[overlay]',overlay)
        self.assertIn('overlay.backdropMode!=="none"',overlay)
        self.assertIn('WlrLayershell.layer:WlrLayer.Top',overlay)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',overlay)
        self.assertNotIn('Qt.alpha(Theme.background, 0.58)',overlay)
        self.assertNotIn('exclusiveZone:',overlay)
        self.assertIn('launcherSurface.inputItem',overlay)
        self.assertIn('launcherSurface.resultsItem',overlay)
        editor=source('modules/settings/pages/LauncherSettingRow.qml')
        self.assertIn('["dim","dim-blur","focus"].indexOf(LauncherStyle.backdrop(',editor)

    def test_distinct_frontends_and_shared_gallery(self):
        styles=source('config/LauncherStyle.qml')
        view=source('components/LauncherView.qml')
        for key in STYLES:
            self.assertIn('key:"'+key+'"',styles)
        for branch in ('root.overviewSidebarWidth','root.quickActionsHeight','classicCategories','root.legacyFrequentHeight','root.recentHeight','detachedInputMaterial','detachedResultsMaterial'):
            self.assertIn(branch,view)
        self.assertIn('LauncherView {',source('components/LauncherStylePreview.qml'))
        self.assertIn('LauncherStylePreview {',source('modules/settings/pages/SettingsLauncherPage.qml'))
        self.assertIn('GridView {',source('components/LauncherResults.qml'))
        self.assertIn('ListView {',source('components/LauncherResults.qml'))
        self.assertIn('root.controller.toolsMode',view)

    def test_native_material_visibility_and_motion_are_independent(self):
        material=source('components/LauncherMaterial.qml')
        view=source('components/LauncherView.qml')
        for token in ('Theme.background','Theme.glassTint','Theme.glassBorderColor','Theme.shadow'):
            self.assertIn(token,material)
        self.assertNotIn('aether',material.lower())
        self.assertNotIn('opacity:',material)
        for part in ('Input','Results'):
            for control in ('GlassEnabled','BackgroundEnabled','OutlineEnabled','Radius','Opacity','Highlights','ShadowIntensity'):
                self.assertIn('detachedLauncher'+part+control,material)
        self.assertIn('border.width: outlineVisible ? 1 : 0',material)
        self.assertIn('materialGlass && outlineVisible',material)
        self.assertIn('materialGlass && backgroundVisible',material)
        self.assertIn('visible:!root.detached',view)
        self.assertIn('SurfaceMotion {',view)
        self.assertIn('Theme.motionEnabled && !SettingsStore.lowMemoryShellMode',view)
        self.assertNotIn('ShaderEffect',view)
        self.assertIn('image.status!==Image.Ready',source('components/LauncherAppIcon.qml'))

    def test_provider_history_is_bounded_and_not_written_to_disk(self):
        usage=source('services/AppUsage.qml')
        self.assertIn('slice(0,8)',usage)
        self.assertIn('entry.payload.length>4096',usage)
        persist=usage.split('function persist()',1)[1]
        self.assertIn('JSON.stringify(usage,',persist)
        self.assertNotIn('recentCommands',persist)


if __name__=='__main__':
    unittest.main(verbosity=2)
