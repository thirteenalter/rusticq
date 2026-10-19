#!/usr/bin/env python3
"""Static/isolated regression for RC3 AI workspace, audio and appearance fix."""
from pathlib import Path
import json, os, subprocess, tempfile, shutil
root = Path(__file__).resolve().parents[1]
def get(rel): return (root / rel).read_text(encoding='utf-8')
ai = get('modules/ai/AiWrapper.qml')
assert 'WlrLayer.Overlay' in ai and 'anchors { top: true; left: true; bottom: true; right: panel.fullMode }' in ai
assert 'Layout.maximumHeight: 48' in ai and 'id: composer' in ai
assert 'AiChats.activeMessages' in ai and 'Text.MarkdownText' in ai
assert 'providerPickerOpen' in ai and 'modelPickerOpen' in ai
assert 'SettingsStore.aiModel = model' in ai
popup = get('modules/main/IndicatorPopup.qml')
audio = get('modules/main/MiniAudio.qml')
assert 'widgetLoader.item.implicitHeight' in popup
assert 'implicitHeight: content.implicitHeight + 24' in audio
assert 'preferredDefaultAudioSource' in audio and 'preferredDefaultAudioSink' in audio
assert 'root.inputDevices' in audio and 'root.outputDevices' in audio
appearance = get('modules/settings/pages/SettingsAppearancePage.qml')
assert 'pick-wallpaper' in appearance and 'pick-font' in appearance and 'install-font' in appearance
assert 'appearancePage.installedFonts' in appearance and 'uiCustomFont' in get('config/SettingsStore.qml')
helper = root/'scripts/rusticq-appearance.py'
res = subprocess.run(['python3', str(helper), 'fonts'], capture_output=True, text=True, timeout=15)
answer=json.loads(res.stdout)
assert answer.get('ok') and isinstance(answer['families'], list) and answer['families']
res = subprocess.run(['python3', str(helper), 'install-font', '/etc/passwd'], capture_output=True,text=True,timeout=15)
assert res.returncode != 0 and not json.loads(res.stdout)['ok']
with tempfile.TemporaryDirectory() as d:
    h=Path(d)
    source=h/'test.otf'
    source.write_bytes((root/'assets/Poppins-Medium.ttf').read_bytes())
    env=os.environ.copy(); env['HOME']=d
    res = subprocess.run(['python3',str(helper),'install-font',str(source)], capture_output=True,text=True,env=env,timeout=30)
    info=json.loads(res.stdout)
    assert info['ok'], info
    assert (h/'.local/share/fonts/rusticq/test.otf').exists()
print('PASS RC3 AI/audio/appearance static contracts and isolated font helper tests')
