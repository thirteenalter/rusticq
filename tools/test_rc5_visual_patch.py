#!/usr/bin/env python3
"""Source contract checks for the no-version-bump widget/launcher/graph patch."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
def get(path):return (r/path).read_text()
service=get('services/SysMonService.qml')
assert 'property var cpuHistory:' in service and 'property var memHistory:' in service
assert 'pushSample()' in service and 'cpuHistory = cpuHistory.concat' in service
chart=get('components/MetricWave.qml')
assert 'ctx.reset()' not in chart
assert 'onSamplesChanged: chart.requestPaint()' in chart
assert 'ctx.stroke()' in chart
assert 'createLinearGradient' in chart
assert 'samples:root.cpuHistory' in get('modules/main/SystemDashboard.qml').replace(' ','') or 'series:root.cpuHistory' in get('modules/main/SystemDashboard.qml').replace(' ','')
wrapper=get('modules/main/DesktopWidgets.qml')
window=get('modules/main/DesktopWidgetWindow.qml')
for kind in ('clock','calendar','system','media','weather','connectivity'):
    assert f'kind: "{kind}"' in wrapper
assert 'WlrLayer.Bottom' in window and 'DragHandler' in window and 'desktop.savePosition()' in window
assert 'margins.left:' in window and 'margins.top:' in window
settings=get('config/SettingsStore.qml')
for token in ('widgetPositions', 'setWidgetPosition', 'resetWidgetPositions', 'widgetPositions: widgetPositions'):
    assert token in settings
launcher=get('modules/main/MiniLauncher.qml')
for token in ('IconImage', 'Quickshell.iconPath', 'AppUsage.noteLaunch', 'AppUsage.togglePinned', 'Pinned & frequently used'):
    assert token in launcher
assert 'import Quickshell.Widgets' in launcher
usage=get('services/AppUsage.qml')
assert 'app-usage.json' in usage and 'function togglePinned' in usage
assert 'singleton AppUsage' in get('services/qmldir')
audio=get('modules/main/MiniAudio.qml')
assert 'border.width: 0' in audio
assert 'widgetLoader.item.advancedOpen' in get('modules/main/IndicatorPopup.qml')
print('RC5 visual patch source checks passed')
