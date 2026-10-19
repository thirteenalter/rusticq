from pathlib import Path
import ast
import json
import subprocess
import tempfile

root = Path(__file__).parents[1]

def check(condition, label):
    if not condition:
        raise AssertionError(label)
    print('PASS', label)

base = (root/'modules/main/Bar.qml').read_text()
check('anchors.horizontalCenterOffset: SettingsStore.centerOffsetX' in base, 'absolute center independent of left/right groups')
check('id: sharedCenterZone' in base and 'active: !barWindow.verticalMode && SettingsStore.absoluteCenter' in base, 'single active center zone')
launcher = (root/'modules/main/MiniLauncher.qml').read_text()
check('RusticQIcon { anchors.centerIn: parent; iconSize: 23' in launcher and 'Icon { icon: "\\ue8b6"' in launcher, 'brand header and magnifying search field')
quick = (root/'modules/quickcontrol/QuickControlCards.qml').read_text()
check('BarWifi { expanded: false;' in quick and 'BarSystem { compactQuick: true }' in quick, 'compact quick cards isolated')
check('Math.min(690, quickCards.preferredContentHeight + 119)'  in (root/'modules/bar/BarWrapper.qml').read_text(), 'responsive compact quick height')
settings = (root/'config/SettingsStore.qml').read_text()
for key in ['absoluteCenter', 'centerOffsetX', 'uiFontFamily','uiFontScale','uiDensity','wallpaperPath','wallpaperBackend']:
    check(f'property ' in settings and f'{key}:' in settings, 'stored setting '+key)
check('singleton AiChats 1.0 AiChats.qml' in (root/'services/qmldir').read_text(), 'AI singleton registered')
ai = (root/'modules/ai/AiWrapper.qml').read_text()
check('Text.MarkdownText' in ai and 'AiChats.activeMessages' in ai, 'AI markdown and chats')
check('active: Store.aiVisible' not in (root/'shell.qml').read_text(), 'AI window kept instantiated when hidden')
check((root/'assets/rusticq-app-icon.svg').exists(), 'branding asset present')
wallpaper = root/'scripts/rusticq-wallpaper.py'
with tempfile.TemporaryDirectory() as tmp:
    result = subprocess.run(['python3',str(wallpaper),'/etc/passwd'],capture_output=True,text=True)
    data = json.loads(result.stdout)
    check(not data['ok'] and result.returncode != 0,'wallpaper rejects outside-home path')
    result = subprocess.run(['python3',str(wallpaper),'--backend','auto',str(Path(tmp)/'none.png')],capture_output=True,text=True)
    check(not json.loads(result.stdout)['ok'], 'wallpaper rejects missing file')

# Delimiters in code, ignoring quoted strings, JS/QML single-line and multiline comments.
def validate_braces(path):
    text = path.read_text()
    if path.name == "AiChats.qml":
        text = "\n".join(line for line in text.splitlines() if 'replace(/!' not in line and '.replace(/<img' not in line)
    pairs={')':'(',']':'[','}':'{'}
    stack=[]; quote=None; comment=None; escaped=False
    i=0
    while i<len(text):
        char=text[i]
        nxt=text[i+1] if i+1<len(text) else ''
        if comment=='//':
            if char=='\n': comment=None
            i+=1;continue
        if comment=='/*':
            if char=='*' and nxt=='/': comment=None;i+=2;continue
            i+=1;continue
        if quote:
            if escaped: escaped=False
            elif char=='\\': escaped=True
            elif char==quote: quote=None
            i+=1;continue
        if char=='/' and nxt=='/': comment='//';i+=2;continue
        if char=='/' and nxt=='*': comment='/*';i+=2;continue
        if char in "\"'`":quote=char;i+=1;continue
        if char in '([{':stack.append((char,i))
        if char in ')]}':
            if not stack or stack[-1][0]!=pairs[char]:
                raise AssertionError(f'{path.relative_to(root)} mismatch {char} at {i}')
            stack.pop()
        i+=1
    if stack: raise AssertionError(f'{path.relative_to(root)} open delimiters {stack[-3:]}')

files=list(root.rglob('*.qml'))
for p in files:validate_braces(p)
print('PASS delimiter structure:',len(files),'QML files')
print('PASS RC3 static regression suite')
