#!/usr/bin/env python3
"""Opt-in, local RusticQ launcher providers. No background indexer or cloud I/O.

Use `search MODE TEXT` for JSON suggestions; `execute MODE PAYLOAD` only after
user picks an item. Actions/paths are allowlisted. `:settings` navigates in QML.
"""
import argparse
import colorsys
import json
import os
import time
from pathlib import Path
import shutil
import subprocess
import sys

# On-demand local search; no permanent index or duplicate launcher.
import importlib.util

def module(filename, name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).parent / filename)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj

MAX_RESULTS = 48
MAX_WALLPAPERS = 1800
MAX_IMAGE_BYTES = 70 * 1024 * 1024
EMOJI = [
    ('😀', 'grinning happy smile face'), ('😂', 'laugh tears joy'), ('😊', 'smiling blush'),
    ('😍', 'heart eyes love'), ('🥳', 'party celebration'), ('😎', 'cool sunglasses'),
    ('🥹', 'happy crying proud'), ('😭', 'crying sad tears'), ('🤔', 'thinking hmm'),
    ('😴', 'sleepy tired'), ('🤯', 'mind blown'), ('💀', 'skull'), ('👍', 'thumbs up yes'),
    ('👎', 'thumbs down no'), ('👏', 'clap applause'), ('🙏', 'thank you please'),
    ('👋', 'wave hello goodbye'), ('💪', 'muscle strong'), ('🤝', 'handshake agree'),
    ('❤️', 'red heart love'), ('🧡', 'orange heart'), ('💛', 'yellow heart'),
    ('💚', 'green heart'), ('💙', 'blue heart'), ('💜', 'purple heart'),
    ('✨', 'sparkles star'), ('⭐', 'star favorite'), ('🔥', 'fire hot'),
    ('🎉', 'confetti celebration'), ('🚀', 'rocket launch'), ('✅', 'check yes'),
    ('❌', 'cross no'), ('⚠️', 'warning'), ('💡', 'light bulb idea'),
    ('🔒', 'lock security'), ('🔑', 'key password'), ('📋', 'clipboard'),
    ('📷', 'camera photo'), ('🖼️', 'picture wallpaper'), ('🎨', 'art palette'),
    ('💻', 'laptop computer'), ('⌨️', 'keyboard'), ('🐧', 'penguin linux'),
    ('🐱', 'cat'), ('🐶', 'dog'), ('🌸', 'flower cherry blossom'),
    ('🌙', 'moon night'), ('☀️', 'sun bright'), ('🌈', 'rainbow'),
    ('☕', 'coffee'), ('🍕', 'pizza'), ('🍀', 'clover luck'),
    ('⚙️', 'settings gear'), ('📁', 'folder files'), ('📝', 'notes memo'),
]
SETTINGS = [
    ('appearance','Appearance','Theme, fonts, accents'),
    ('bar','Bar','Layouts, alignment and spacing'),
    ('modules','Modules','Per-layout icon visibility'),
    ('widgets','Desktop Widgets','Widgets and desktop tools'),
    ('dock','Dock','Dock positioning and apps'),
    ('notes','Notes & Kanban','Local todo lists and task board'),
    ('launcher','App Launcher','Search, favorites and sizing'),
    ('display','Displays','Resolution, refresh rate and scaling'),
    ('os','OS information','Operating system details'),
    ('hardware','Hardware','CPU, GPU and sensors'),
    ('apps','Installed Apps','Manage desktop applications'),
    ('storage','Storage','Disks and cache'),
    ('updates','Arch Updater','Package updates'),
    ('shortcuts','Keyboard Shortcuts','Keybinding manager'),
    ('integration','Integration','Doctor, backup and dependencies'),
    ('ai','AI providers','Provider settings'),
    ('about','About RusticQ','Version and project information'),
]
IMAGE_TYPES = {'.png','.jpg','.jpeg','.webp','.bmp'}


def item(label, detail, action, payload, icon=''):
    return {'label': label, 'detail': detail, 'action': action,
            'payload': payload, 'icon': icon}


def wallpaper_roots(home):
    return [home/'Pictures'/'Wallpapers', home/'Wallpapers',
            home/'.local'/'share'/'wallpapers', home/'Pictures']


def wallpapers(search, home=None):
    home = (Path.home() if home is None else Path(home)).resolve()
    visited = set()
    candidates = []
    for base in wallpaper_roots(home):
        if not base.is_dir() or base.is_symlink():
            continue
        # Limit descent and never follow directory symlinks. No system-wide scan.
        for root, dirs, names in os.walk(base, followlinks=False):
            path = Path(root)
            level = len(path.relative_to(base).parts)
            dirs[:] = sorted(d for d in dirs if level < 3 and not (path/d).is_symlink() and not d.startswith('.'))[:45]
            for filename in sorted(names):
                image = path/filename
                if image.suffix.lower() not in IMAGE_TYPES or image.is_symlink():
                    continue
                try:
                    resolved = image.resolve(strict=True)
                    resolved.relative_to(home)
                    if not resolved.is_file() or resolved.stat().st_size > MAX_IMAGE_BYTES:
                        continue
                except (OSError, ValueError):
                    continue
                if resolved in visited:
                    continue
                visited.add(resolved)
                candidates.append(resolved)
                if len(candidates) >= MAX_WALLPAPERS:
                    break
            if len(candidates) >= MAX_WALLPAPERS:
                break
        if len(candidates) >= MAX_WALLPAPERS:
            break
    text = search.casefold()
    return [item(p.stem, str(p.relative_to(home)), 'wallpaper', str(p), '🖼️')
            for p in candidates if text in p.name.casefold() or text in str(p.parent).casefold()][:MAX_RESULTS]


def search(mode, text='', home=None):
    if not isinstance(text, str) or len(text) > 130:
        raise ValueError('Search query is too long')
    q = text.strip().casefold()
    if mode in ('files', 'folders', 'windows', 'workspaces'):
        desktop = module('rusticq-desktop-search.py', 'rusticq_desktop_search')
        if mode in ('files', 'folders'):
            return desktop.file_results(text, folders=mode == 'folders', home=home)
        return desktop.search_hypr(mode, text)
    if mode == 'notes':
        notes = module('rusticq-notes.py', 'rusticq_notes')
        entries = []
        if text.startswith('+') and text[1:].strip():
            title = notes.validate_title(text[1:].strip())
            entries.append(item('Add note: ' + title, 'New Kanban note · To Do', 'note-add', title, '📝'))
        query = text[1:].strip() if text.startswith('+') else text
        for note in notes.op('list', query)['items']:
            entries.append(item(note['title'], note['stage'].upper() + ' · Enter to advance Kanban stage',
                                'note-toggle', note['id'], '📝'))
        return entries[:MAX_RESULTS]
    if mode == 'emoji':
        return [item(emoji, tags, 'emoji', emoji, emoji)
                for emoji, tags in EMOJI if q in tags or q in emoji][:MAX_RESULTS]
    if mode == 'settings':
        return [item(title, detail, 'settings', tab, '⚙️')
                for tab,title,detail in SETTINGS
                if q in (title+' '+detail+' '+tab).casefold()][:MAX_RESULTS]
    if mode == 'wallpaper':
        return wallpapers(q, home)
    if mode == 'color':
        return [item('Pick screen color', 'Use hyprpicker; copy sampled HEX to clipboard', 'color', 'pick', '🎨')]
    if mode == 'ocr':
        return [item('OCR screen region', 'Select a region; recognize text locally and copy it', 'ocr', 'region', '📷')]
    raise ValueError('Unknown launcher provider')


def call(argv, *, timeout=40, input_data=None):
    try:
        result = subprocess.run(argv, input=input_data, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError('Tool unavailable or timed out') from exc
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).decode('utf-8', 'replace').strip()[:240] or 'Tool failed')
    return result.stdout


def clipboard(data):
    if not shutil.which('wl-copy'):
        raise RuntimeError('Install wl-clipboard to copy text')
    call(['wl-copy', '--type', 'text/plain;charset=utf-8'], input_data=data.encode('utf-8'), timeout=5)


def execute(mode, payload):
    if mode in ('file', 'folder', 'window', 'workspace'):
        desktop = module('rusticq-desktop-search.py', 'rusticq_desktop_search')
        return desktop.open_item(mode, payload)
    if mode in ('note-add', 'note-toggle'):
        notes = module('rusticq-notes.py', 'rusticq_notes')
        result = notes.op('add', payload) if mode == 'note-add' else notes.op('toggle', payload)
        return result['title'] + ' · ' + result['stage']
    if mode == 'emoji':
        if payload not in {symbol for symbol,_ in EMOJI}:
            raise ValueError('Emoji is not in the picker catalogue')
        clipboard(payload)
        return 'Copied ' + payload + ' to clipboard'
    if mode == 'wallpaper':
        path = Path(payload).expanduser().resolve(strict=True)
        home = Path.home().resolve()
        try:
            path.relative_to(home)
        except ValueError as exc:
            raise ValueError('Wallpaper must be within your home directory') from exc
        if not path.is_file() or path.suffix.lower() not in IMAGE_TYPES or path.stat().st_size > MAX_IMAGE_BYTES:
            raise ValueError('Unsupported or oversized wallpaper')
        result = call(['python3', str(Path(__file__).resolve().parent/'rusticq-wallpaper.py'), str(path)])
        response = json.loads(result)
        if response.get('ok') is not True:
            raise RuntimeError(response.get('message', 'Wallpaper backend failed'))
        return response.get('message', 'Wallpaper applied')
    if mode == 'color':
        if payload != 'pick':
            raise ValueError('Invalid color picker command')
        if not shutil.which('hyprpicker'):
            raise RuntimeError('Install hyprpicker for color sampling')
        if not shutil.which('wl-copy'):
            raise RuntimeError('Install wl-clipboard for color copying')
        color = call(['hyprpicker', '-f', 'hex'], timeout=75).decode('utf-8', 'replace').strip().upper()
        import re
        if not re.fullmatch(r'#[0-9A-F]{6}', color):
            raise RuntimeError('Hyprpicker did not return a valid HEX color')
        clipboard(color)
        r,g,b = (int(color[i:i+2],16) for i in (1,3,5))
        hue, lightness, saturation = colorsys.rgb_to_hls(r/255,g/255,b/255)
        return ('Copied ' + color + ' · RGB ' + str((r,g,b)) +
                ' · HSL (' + str(round(hue*360)) + '°, ' +
                str(round(saturation*100)) + '%, ' + str(round(lightness*100)) + '%)')
    if mode == 'ocr':
        if payload != 'region':
            raise ValueError('Invalid OCR command')
        for tool in ('grim','slurp','tesseract','wl-copy'):
            if not shutil.which(tool):
                raise RuntimeError('Install ' + tool + ' for local OCR')
        geometry = call(['slurp'], timeout=90).decode('utf-8', 'replace').strip()
        import re
        if not re.fullmatch(r'[0-9]+,[0-9]+ [1-9][0-9]*x[1-9][0-9]*', geometry):
            raise RuntimeError('Invalid or cancelled selection')
        picture = call(['grim','-g',geometry,'-'], timeout=25)
        if not picture or len(picture) > 30 * 1024 * 1024:
            raise RuntimeError('Capture empty or exceeds 30 MiB')
        extracted = call(['tesseract','stdin','stdout'], input_data=picture, timeout=50).decode('utf-8', 'replace').strip()
        if not extracted:
            raise RuntimeError('No readable text in selected region')
        clipboard(extracted)
        return 'Copied ' + str(len(extracted)) + ' OCR characters (local only)'
    raise ValueError('Unsupported executable launcher action')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('verb', choices=('search','execute','execute-later'))
    parser.add_argument('mode', choices=('emoji','settings','wallpaper','color','ocr','files','folders','windows','workspaces','notes','file','folder','window','workspace','note-add','note-toggle'))
    parser.add_argument('value', nargs='?', default='')
    args = parser.parse_args()
    try:
        if args.verb == 'search':
            output = {'ok':True,'mode':args.mode,'query':args.value,
                      'items':search(args.mode,args.value)}
        else:
            if args.verb == 'execute-later':
                if args.mode not in ('color', 'ocr'):
                    raise ValueError('Delayed actions only support screen tools')
                time.sleep(.65)  # Wait until the launcher layer has disappeared.
            output = {'ok':True,'message':execute(args.mode,args.value)}
        print(json.dumps(output,ensure_ascii=False))
        if args.verb == 'execute-later' and shutil.which('notify-send'):
            subprocess.run(['notify-send', 'RusticQ tools', output['message']],
                           capture_output=True, timeout=3, check=False)
    except (ValueError, OSError, RuntimeError, json.JSONDecodeError) as exc:
        message = str(exc)
        print(json.dumps({'ok':False,'mode':args.mode,'message':message},ensure_ascii=False))
        if args.verb == 'execute-later' and shutil.which('notify-send'):
            subprocess.run(['notify-send', '-u', 'critical', 'RusticQ tool failed', message[:200]],
                           capture_output=True, timeout=3, check=False)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
