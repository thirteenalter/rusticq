"""Audited scalar options for the Hyprland settings studio.

Runtime getoption is authoritative: an entry here never implies support.
Defaults are reset targets, never presented as measured/effective values.
"""

CATEGORIES = [
    ('overview', 'Overview', 'General', '\ue871'),
    ('appearance', 'Appearance', 'General', '\ue40a'),
    ('effects', 'Effects', 'General', '\ue3ae'),
    ('animations', 'Animations', 'General', '\ue1c4'),
    ('layouts', 'Layouts', 'Window Management', '\ue871'),
    ('workspaces', 'Workspaces', 'Window Management', '\ue1bd'),
    ('window-rules', 'Window Rules', 'Window Management', '\ue069'),
    ('layer-rules', 'Layer Rules', 'Window Management', '\ue53b'),
    ('displays', 'Displays', 'Devices', '\ue30b'),
    ('keyboard', 'Keyboard', 'Devices', '\ue312'),
    ('mouse', 'Mouse', 'Devices', '\ue323'),
    ('trackpad', 'Trackpad', 'Devices', '\ue328'),
    ('gestures', 'Gestures', 'Devices', '\ue9ec'),
    ('shortcuts', 'Keyboard Shortcuts', 'Automation', '\ue5d3'),
    ('autostart', 'Autostart', 'Automation', '\ue037'),
    ('environment', 'Environment Variables', 'Automation', '\ue8b8'),
    ('performance', 'Performance', 'Advanced', '\ue9e4'),
    ('miscellaneous', 'Miscellaneous', 'Advanced', '\ue8b8'),
    ('plugins', 'Plugins', 'Advanced', '\ue87b'),
    ('editor', 'Configuration Editor', 'Advanced', '\ue86f'),
    ('backups', 'Backup & Restore', 'Advanced', '\ue889'),
]

OPTIONS = []


def option(page, key, label, default, limits=None, choices=None, description='', depends=''):
    kind = 'bool' if isinstance(default, bool) else 'int' if isinstance(default, int) else 'float' if isinstance(default, float) else 'string'
    OPTIONS.append(dict(id=key, page=page, label=label, description=description or key,
                        type=kind, default=default, minimum=limits[0] if limits else None,
                        maximum=limits[1] if limits else None, choices=choices or [],
                        dependencies=depends, formats=['lua', 'hyprlang'], runtime=True,
                        persistent=True, restart=False, supportedVersions='runtime-probed'))


for key, label, default, limits in [
    ('decoration:rounding', 'Window rounding', 0, (0, 20)),
    ('decoration:rounding_power', 'Rounding power', 2.0, (1, 10)),
    ('general:border_size', 'Border size', 1, (0, 20)),
    ('general:gaps_in', 'Inner window gaps', 5, (0, 80)),
    ('general:gaps_out', 'Outer window gaps', 20, (0, 120)),
    ('general:gaps_workspaces', 'Workspace gaps', 0, (0, 120)),
    ('decoration:active_opacity', 'Active window opacity', 1.0, (0.1, 1)),
    ('decoration:inactive_opacity', 'Inactive window opacity', 1.0, (0.1, 1)),
    ('decoration:fullscreen_opacity', 'Fullscreen opacity', 1.0, (0.1, 1)),
    ('decoration:dim_strength', 'Inactive dim strength', 0.5, (0, 1)),
]: option('appearance', key, label, default, limits)
option('appearance', 'decoration:dim_inactive', 'Dim inactive windows', False)
option('appearance', 'general:col.active_border', 'Active border color', 'rgba(ffffffff)')
option('appearance', 'general:col.inactive_border', 'Inactive border color', 'rgba(444444ff)')

for section, rows in {
    'blur': [('enabled', 'Blur', True, None), ('size', 'Blur size', 8, (1, 40)),
             ('passes', 'Blur passes', 1, (1, 8)), ('noise', 'Noise', 0.0117, (0, 1)),
             ('contrast', 'Contrast', 0.8916, (0, 2)), ('brightness', 'Brightness', 1.0, (0, 2)),
             ('vibrancy', 'Vibrancy', 0.1696, (0, 1)), ('ignore_opacity', 'Ignore opacity', True, None)],
    'shadow': [('enabled', 'Shadows', True, None), ('range', 'Shadow range', 4, (0, 80)),
               ('render_power', 'Shadow rendering power', 3, (1, 4)),
               ('sharp', 'Sharp shadows', False, None), ('ignore_window', 'Ignore window interior', True, None),
               ('color', 'Shadow color', 'rgba(1a1a1aee)', None)]
}.items():
    for key, label, default, limits in rows:
        option('effects', 'decoration:' + section + ':' + key, label, default, limits,
               depends='' if key == 'enabled' else 'decoration:' + section + ':enabled')
option('animations', 'animations:enabled', 'Enable animations', True)
option('layouts', 'general:layout', 'Tiling layout', 'dwindle', choices=['dwindle', 'master'])
for key, label, default, limits in [
    ('dwindle:default_split_ratio', 'Split ratio', 1.0, (0.1, 1.9)),
    ('dwindle:pseudotile', 'Pseudotiling', False, None),
    ('dwindle:preserve_split', 'Preserve split direction', False, None),
    ('dwindle:smart_split', 'Smart split', False, None),
    ('dwindle:smart_resizing', 'Smart resizing', True, None),
    ('master:mfact', 'Master area ratio', 0.55, (0.1, 0.9)),
    ('master:smart_resizing', 'Resize master windows together', True, None),
    ('general:resize_on_border', 'Resize using window borders', False, None),
]: option('layouts', key, label, default, limits)
option('layouts', 'master:orientation', 'Master position', 'left', choices=['left', 'right', 'top', 'bottom', 'center'])
for key, label, default, limits in [
    ('input:repeat_rate', 'Repeat rate', 25, (1, 100)),
    ('input:repeat_delay', 'Repeat delay', 600, (100, 2000)),
    ('input:numlock_by_default', 'NumLock at startup', False, None),
]: option('keyboard', key, label, default, limits)
for key, label, default in [('kb_layout', 'Keyboard layout', 'us'), ('kb_variant', 'Variant', ''),
                             ('kb_options', 'XKB options', ''), ('kb_model', 'XKB model', '')]:
    option('keyboard', 'input:' + key, label, default)
option('mouse', 'input:sensitivity', 'Pointer sensitivity', 0.0, (-1, 1))
option('mouse', 'input:accel_profile', 'Acceleration profile', '', choices=['', 'flat', 'adaptive'])
option('mouse', 'input:natural_scroll', 'Natural scrolling', False)
option('mouse', 'input:left_handed', 'Left handed', False)
option('mouse', 'input:scroll_factor', 'Scroll multiplier', 1.0, (0.1, 10))
option('mouse', 'input:follow_mouse', 'Focus follows mouse', 1, (0, 3))
for key, label, default in [('tap-to-click', 'Tap to click', True), ('natural_scroll', 'Natural scrolling', False),
                             ('disable_while_typing', 'Disable while typing', True),
                             ('tap-and-drag', 'Tap and drag', True), ('drag_lock', 'Drag lock', False)]:
    option('trackpad', 'input:touchpad:' + key, label, default)
option('trackpad', 'input:touchpad:clickfinger_behavior', 'Clickfinger behavior', False)
option('trackpad', 'input:touchpad:scroll_factor', 'Scroll sensitivity', 1.0, (0.1, 10))
for key, label, default, limits in [
    ('gestures:workspace_swipe_distance', 'Workspace swipe distance', 300, (50, 2000)),
    ('gestures:workspace_swipe_invert', 'Invert workspace swipe', True, None),
    ('gestures:workspace_swipe_forever', 'Continue through workspaces', False, None),
    ('gestures:workspace_swipe_cancel_ratio', 'Swipe cancel ratio', 0.5, (0, 1)),
]: option('gestures', key, label, default, limits)
for key, label, default, limits in [
    ('misc:vfr', 'Variable frame rate', True, None),
    ('misc:vrr', 'Variable refresh rate', 0, (0, 3)),
    ('render:direct_scanout', 'Direct scanout', 0, (0, 2)),
    ('render:explicit_sync', 'Explicit synchronization', 2, (0, 2)),
    ('cursor:no_hardware_cursors', 'Software cursor mode', 2, (0, 2)),
    ('render:expand_undersized_textures', 'Expand undersized textures', True, None),
]: option('performance', key, label, default, limits)
for key, label, default, limits in [
    ('misc:focus_on_activate', 'Focus on activation', False, None),
    ('misc:mouse_move_enables_dpms', 'Wake displays on pointer movement', False, None),
    ('misc:key_press_enables_dpms', 'Wake displays on keypress', False, None),
    ('misc:exit_window_retains_fullscreen', 'Retain fullscreen after closing window', False, None),
    ('cursor:no_warps', 'Disable cursor warping', False, None),
    ('cursor:inactive_timeout', 'Hide inactive cursor after seconds', 0, (0, 120)),
    ('cursor:warp_on_change_workspace', 'Warp cursor on workspace change', 0, (0, 2)),
]: option('miscellaneous', key, label, default, limits)

BY_ID = {o['id']: o for o in OPTIONS}
PRESETS = {
    'macOS-inspired': {'decoration:rounding': 14, 'general:border_size': 1, 'general:gaps_in': 6,
                       'general:gaps_out': 12, 'decoration:blur:enabled': True, 'decoration:shadow:enabled': True},
    'Minimal': {'general:border_size': 1, 'general:gaps_in': 3, 'general:gaps_out': 6, 'decoration:rounding': 6},
    'Glassmorphism': {'decoration:blur:enabled': True, 'decoration:blur:size': 8,
                     'decoration:active_opacity': 0.96, 'decoration:inactive_opacity': 0.9},
    'Performance': {'decoration:blur:enabled': False, 'decoration:shadow:enabled': False,
                    'animations:enabled': False, 'misc:vfr': True},
    'Balanced': {'decoration:blur:enabled': True, 'decoration:blur:passes': 2, 'misc:vfr': True},
}
