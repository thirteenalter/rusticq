#!/usr/bin/env python3
"""RusticQ alpha-1 regression checks (no Quickshell/Hyprland runtime required)."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []
def read(relative): return (root / relative).read_text(encoding="utf-8")
def require(test, message):
    if not test: errors.append(message)

bar = read('modules/main/Bar.qml')
popup = read('modules/main/IndicatorPopup.qml')
clock = read('components/Clock.qml')
weather = read('components/Weather.qml')
service = read('services/WeatherService.qml')
seg = read('components/InfoSegment.qml')

actions = ['weather', 'time', 'date', 'wifi', 'bluetooth', 'battery', 'audio']
for kind in actions:
    require('"' + kind + '"' in popup, 'popup missing kind: ' + kind)
for kind, component in [('weather', 'MiniWeather'), ('time', 'MiniTime'), ('date', 'MiniDate')]:
    require(f'{component} {{' in popup, 'popup lacks ' + component)
    require((root / 'modules/main' / (component + '.qml')).is_file(), 'missing ' + component)
    require(f'openMini("{kind}"' in bar, 'bar missing click routing for ' + kind)
require('mapFromItem(trayWeather' in bar and 'mapFromItem(trayClock' in bar, 'anchor must use QsWindow.mapFromItem')
require('"ddd, dd MMM"' in clock and '"dddd, dd MMM"' in clock, 'weekday formatting missing')
require('SystemClock.Seconds' in read('modules/main/MiniTime.qml'), 'time widget must update every second')
require('gridDate' not in read('modules/main/MiniDate.qml') and 'dayAt(index)' in read('modules/main/MiniDate.qml'), 'date grid missing')
require('WeatherService.icon' in weather, 'weather not using condition glyph')
require('"--°"' in weather, 'weather fallback missing')
require('function refresh()' in service, 'weather refresh missing')
require('readonly property int barTextSize: 12' in read('config/Theme.qml'), 'shared typography token absent')
require('font.family: Fonts.poppins.name' in seg and 'font.weight: Font.Medium' in seg, 'info font inconsistent')
require('"RusticQ · Alpha 3 RC3"' in read('modules/settings/SettingsWindow.qml'), 'RusticQ branding missing')
require('icon: "\\ueb8e"' in read('components/Arch.qml'), 'launcher not Material Symbol')
require('import "../../components"' in read('modules/power/PowerMenu.qml'), 'power menu has no Material Icon import')
require('            Icon {\n                icon: btn.icon' in read('modules/power/PowerMenu.qml'), 'power menu still using Text for icons')

# Every literal Material Symbols codepoint must exist in the bundled google.ttf.
try:
    from fontTools.ttLib import TTFont
except ImportError:
    print('NOTE: fontTools not available: skipping font cmap check (other checks still run)')
else:
    font = TTFont(root / 'assets/google.ttf')
    chars = font.getBestCmap()
    for source in root.rglob('*.qml'):
        for value in re.findall(r'\\u([eEfF][0-9a-fA-F]{3})', source.read_text(encoding='utf-8')):
            require(int(value, 16) in chars,
                    str(source.relative_to(root)) + ' uses missing Google glyph U+' + value.upper())

if errors:
    for issue in errors: print('FAIL:', issue)
    sys.exit(1)
print('PASS: RusticQ alpha-1 icon coverage, widget wiring, branding and visual tokens')
