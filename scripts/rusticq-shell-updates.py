#!/usr/bin/env python3
"""Safe, opt-in RusticQ shell updates independent of Omarchy/pacman updates.

No root permissions, no running-shell termination, no downloads on status.
A complete, checksummed GitHub release asset (never a patch ZIP) or an
explicit local source becomes the next-login installed RusticQ shell.
"""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import zipfile

HOME = Path.home()
XDG_DATA = Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share')
XDG_STATE = Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state')
SHELL = XDG_DATA / 'rusticq' / 'shell'
INTEGRATION = XDG_STATE / 'rusticq' / 'integration'
MANIFEST = INTEGRATION / 'manifest.json'
STATE_DIR = XDG_STATE / 'rusticq' / 'shell-updates'
STATE_FILE = STATE_DIR / 'status.json'
LOCK = STATE_DIR / 'update.lock'
LOCAL = HOME / 'dev' / 'quickshell'
API = 'https://api.github.com/repos/thirteenalter/rusticq/releases'
REPO_URL = 'https://github.com/thirteenalter/rusticq'
MAX_ZIP = 65 * 1024 * 1024
MAX_EXPANDED = 160 * 1024 * 1024
MAX_FILES = 2600
OMIT = {'.git', '.venv', '__pycache__', '.pytest_cache', 'node_modules', 'dist', 'build', '.rusticq-patch-backup'}
PRIVATE = {'user-settings.json', 'app-usage.json', '.env', '.env.local'}
PRESERVE = {'user-settings.json', 'app-usage.json'}
REQUIRED = ['shell.qml', 'config/SettingsStore.qml', 'scripts/rustiq-desktop-integration.py',
            'modules/settings/pages/SettingsIntegrationPage.qml']


class UpdateError(Exception):
    pass


def emit(value):
    print(json.dumps(value, ensure_ascii=False))


def state_save(**values):
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    if STATE_DIR.is_symlink():
        raise UpdateError('Unsafe update state folder')
    previous = {}
    if STATE_FILE.is_file() and not STATE_FILE.is_symlink():
        try:
            previous = json.loads(STATE_FILE.read_text(encoding='utf8'))
        except (ValueError, OSError):
            pass
    previous.update(values)
    previous['updated'] = int(time.time())
    tmp = STATE_DIR / ('.status-' + str(os.getpid()))
    with open(tmp, 'w', encoding='utf8') as f:
        json.dump(previous, f, indent=2)
        f.flush(); os.fsync(f.fileno())
    tmp.chmod(0o600)
    os.replace(tmp, STATE_FILE)


def state_read():
    if STATE_FILE.exists() and not STATE_FILE.is_symlink():
        try:
            return json.loads(STATE_FILE.read_text(encoding='utf8'))
        except (OSError, ValueError):
            pass
    return {}


def installed():
    if not MANIFEST.is_file() or MANIFEST.is_symlink():
        raise UpdateError('Permanent RusticQ integration is not installed. Enable it under Settings → Integration first.')
    try:
        manifest = json.loads(MANIFEST.read_text(encoding='utf8'))
    except (OSError, ValueError) as e:
        raise UpdateError('Installed integration manifest cannot be read: ' + str(e)) from e
    if manifest.get('installed_shell') != str(SHELL) or SHELL.is_symlink() or not SHELL.is_dir():
        raise UpdateError('Installed shell path does not match manifest; refusing to replace unknown files.')
    if not (SHELL / 'shell.qml').is_file():
        raise UpdateError('Installed shell.qml missing; refusing update.')
    return manifest


def destination_for(target):
    if target not in ('installed', 'dev'):
        raise UpdateError('Target must be installed or dev.')
    return SHELL if target == 'installed' else LOCAL


def histories(target):
    path = destination_for(target)
    return sorted((f for f in path.parent.glob(path.name + '-before-update-*')
                   if f.is_dir() and not f.is_symlink()), reverse=True)


def assert_target(target):
    path = destination_for(target)
    if target == 'installed':
        installed()
    else:
        if path.is_symlink() or not path.is_dir():
            raise UpdateError('Development source missing: ' + str(path))
        validate_tree(path)
    return path


def target_state(target):
    return state_read().get('targets', {}).get(target, {})


def target_save(target, **values):
    previous = state_read()
    history = dict(previous.get('targets') or {})
    latest = dict(history.get(target) or {})
    latest.update(values)
    history[target] = latest
    state_save(targets=history, last_target=target, **values)


def current_status():
    st = state_read()
    active = MANIFEST.is_file() and SHELL.is_dir() and not SHELL.is_symlink()
    targets = st.get('targets') or {}
    current_target = st.get('last_target','installed')
    stamp = targets.get(current_target, {})
    installed_backups = len(histories('installed'))
    dev_backups = len(histories('dev'))
    return dict(ok=True, installed=active, installed_path=str(SHELL), local_path=str(LOCAL),
                dev_ready=LOCAL.is_dir() and (LOCAL / 'shell.qml').is_file(),
                source=stamp.get('source', st.get('source', 'preinstalled')),
                installed_tag=targets.get('installed', {}).get('installed_tag', st.get('installed_tag','')),
                dev_tag=targets.get('dev', {}).get('installed_tag',''),
                checked_tag=st.get('checked_tag', ''), release=st.get('release', {}),
                update_available=st.get('update_available', False),
                state=st.get('state', 'idle'), phase=st.get('phase', ''), progress=st.get('progress', 0),
                message=st.get('message', ''), changed=st.get('changed', []),
                backup=st.get('backup', ''), backups=installed_backups,
                backups_installed=installed_backups, backups_dev=dev_backups,
                ready_for_next_login=st.get('state') == 'installed' and current_target == 'installed',
                last_target=current_target,
                last_update=st.get('last_update', 0), repository=REPO_URL)


@contextlib.contextmanager
def exclusive():
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    if STATE_DIR.is_symlink() or LOCK.is_symlink():
        raise UpdateError('Unsafe updater lock path')
    fd = os.open(LOCK, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as e:
            raise UpdateError('Another shell update is still running.') from e
        yield
    finally:
        os.close(fd)


def curl_bytes(url, limit=4*1024*1024):
    if not (url.startswith('https://api.github.com/') or url.startswith('https://github.com/thirteenalter/rusticq/releases/download/')):
        raise UpdateError('Unexpected release download URL; only official RusticQ GitHub URLs are allowed.')
    curl = shutil.which('curl')
    if not curl:
        raise UpdateError('curl is not installed; install curl to check GitHub Releases.')
    proc = subprocess.run([curl, '--fail', '--silent', '--show-error', '--location',
             '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '9',
             '--max-time', '50', '--max-filesize', str(limit), '-H', 'Accept: application/vnd.github+json',
             '-H', 'User-Agent: RusticQ-Shell-Updater/1', url],
             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=55)
    if proc.returncode != 0:
        raise UpdateError('GitHub request failed: ' + proc.stderr.decode('utf8', 'replace').strip()[:250])
    if len(proc.stdout) > limit:
        raise UpdateError('GitHub response exceeds permitted size.')
    return proc.stdout


def releases_get(tag=''):
    if tag and not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', tag):
        raise UpdateError('Invalid GitHub release tag.')
    # Include prereleases; /releases/latest omits many prerelease tags.
    url = API + ('/tags/' + tag if tag else '?per_page=30')
    data = json.loads(curl_bytes(url))
    if isinstance(data, list):
        data = next((r for r in data if not r.get('draft')), None)
    if not isinstance(data, dict) or not data.get('tag_name') or data.get('draft'):
        raise UpdateError('No published RusticQ GitHub Release found.')
    return data


def choose_full_asset(release):
    assets = [a for a in release.get('assets', []) if isinstance(a, dict)
              and a.get('state') == 'uploaded' and a.get('name', '').lower().endswith('.zip')
              and a.get('size', 0) <= MAX_ZIP and a.get('size', 0) > 0
              and 'patch' not in a.get('name','').lower()]
    preferred = [a for a in assets if a['name'].lower().endswith('-full.zip')]
    if not preferred:
        preferred = [a for a in assets if a['name'].lower() in ('quickshell.zip', 'rusticq.zip')]
    checksum_assets = any(str(a.get('name', '')).upper() in ('SHA256SUMS', 'SHA256SUMS.TXT', 'CHECKSUMS.SHA256')
                          for a in release.get('assets', []) if isinstance(a, dict))
    if preferred and (str(preferred[0].get('digest','')).startswith('sha256:') or checksum_assets):
        return preferred[0]
    # GitHub always offers a source snapshot, even when the maintainer has not
    # uploaded binary release assets. Explicitly identify this as NOT possessing
    # a separately published checksum. Trust comes from official GitHub HTTPS.
    url = str(release.get('zipball_url') or '')
    expected = 'https://api.github.com/repos/thirteenalter/rusticq/zipball/'
    if url.startswith(expected) and re.fullmatch(r'[A-Za-z0-9._-]{1,120}', url[len(expected):]):
        return dict(name='GitHub source ZIP (' + str(release['tag_name']) + ')',
                    size=0, digest='', browser_download_url=url, _source_archive=True)
    if preferred:  # Verification will still fail closed without a published digest.
        return preferred[0]
    raise UpdateError('Release has no full ZIP with checksum and no official GitHub source ZIP. Cannot update.')


def release_summary(release):
    full = choose_full_asset(release)
    digest = full.get('digest') or ''
    return dict(tag=str(release['tag_name']), title=release.get('name') or release['tag_name'],
                published_at=release.get('published_at') or '', asset=full['name'],
                size=full['size'], digest=digest, source_archive=bool(full.get('_source_archive')),
                checksum_published=bool(digest.startswith('sha256:')),
                url=REPO_URL + '/releases/tag/' + release['tag_name'])


def check_updates(tag=''):
    release = releases_get(tag)
    summary = release_summary(release)
    old = state_read()
    last = old.get('targets', {}).get('dev', {}).get('installed_tag', '') or old.get('installed_tag', '')
    # Never pretend a previously installed local build is older by version alone.
    available = bool(last) and summary['tag'] != last
    state_save(checked_tag=summary['tag'], release=summary, update_available=available,
               message=('Different GitHub release available; ready for explicit download' if available else
                        'Release found. Current installed version is unknown; review before installing.' if not last else
                        'This release tag is already installed'),
               state=old.get('state', 'idle'), progress=old.get('progress', 0),
               phase=old.get('phase', 'GitHub release metadata checked'))
    return dict(ok=True, update_available=available, release=summary,
                installed_tag=last, message=state_read()['message'])


def validate_tree(tree):
    for need in REQUIRED:
        file = tree / need
        if not file.is_file() or file.is_symlink():
            raise UpdateError('Invalid shell update; missing source file ' + need)
    if (tree / 'user-settings.json').is_symlink():
        raise UpdateError('Unsafe user settings symlink in shell source.')


def safe_copy_source(source, stage, destination=None):
    source = source.resolve(strict=True)
    target = (destination or SHELL).resolve()
    if not source.is_dir() or source == target or target in source.parents:
        raise UpdateError('Local source must be a separate directory, not the installed shell.')
    validate_tree(source)
    count = [0]; size = [0]
    def ignore(current, names):
        ignored = set()
        for name in names:
            child = Path(current) / name
            if name in OMIT or name in PRIVATE or child.is_symlink() or name.endswith(('.pyc', '.key', '.pem', '.log')):
                ignored.add(name)
            elif child.is_file():
                count[0] += 1; size[0] += child.stat().st_size
                if count[0] > MAX_FILES or size[0] > MAX_EXPANDED:
                    raise UpdateError('Local shell source exceeds updater size/file limits.')
        return ignored
    shutil.copytree(source, stage, ignore=ignore, symlinks=False)
    validate_tree(stage)


def extract_full_zip(archive, stage, source_archive=False):
    if archive.stat().st_size > MAX_ZIP:
        raise UpdateError('Release ZIP too large.')
    entries = []
    total = 0
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            if item.is_dir():
                continue
            path = Path(item.filename)
            if path.is_absolute() or '..' in path.parts or len(path.parts) < 2 or '\\' in item.filename:
                raise UpdateError('Invalid ZIP entry path.')
            if not source_archive and path.parts[0] != 'quickshell':
                raise UpdateError('Invalid ZIP structure; expected quickshell/... paths only.')
            if source_archive and not path.parts[0].startswith('thirteenalter-rusticq-'):
                raise UpdateError('Unexpected source archive prefix.')
            if any(part in OMIT for part in path.parts) or path.name in PRIVATE:
                continue
            if (item.external_attr >> 16) & 0o170000 == stat.S_IFLNK:
                raise UpdateError('Release ZIP symlinks are forbidden.')
            if (item.external_attr >> 16) & 0o170000 not in (0, stat.S_IFREG):
                raise UpdateError('Release ZIP contains special filesystem entry.')
            total += item.file_size
            if len(entries) >= MAX_FILES or total > MAX_EXPANDED or item.file_size > 40 * 1024 * 1024:
                raise UpdateError('Release ZIP exceeds safe extraction limits.')
            entries.append((item, Path(*path.parts[1:])))
        stage.mkdir(parents=True)
        for item, rel in entries:
            path = stage / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.parent.is_symlink() or path.exists():
                raise UpdateError('Unsafe or duplicate release ZIP entry: ' + str(rel))
            with z.open(item) as src, open(path, 'xb') as dst:
                shutil.copyfileobj(src, dst)
            # Startup scripts are executed by Python directly; preserve only exec bits
            path.chmod(0o755 if rel.suffix in ('.py', '.sh') else 0o644)
    validate_tree(stage)


def filehash(path):
    result = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024*512), b''):
            result.update(chunk)
    return result.hexdigest()


def verify_checksum(archive, release, asset):
    expected = str(asset.get('digest') or '')
    if expected.startswith('sha256:') and re.fullmatch('[0-9a-fA-F]{64}', expected[7:]):
        expected = expected[7:]
    else:
        # Checksum file published as part of same Release if GitHub digest field isn't present.
        checksum = next((a for a in release.get('assets', []) if a.get('name','').upper() in ('SHA256SUMS','SHA256SUMS.TXT','CHECKSUMS.SHA256')),
                        None)
        if not checksum:
            raise UpdateError('Full ZIP has no published SHA256 digest or SHA256SUMS asset. Refusing unverified automatic installation.')
        checks = curl_bytes(checksum.get('browser_download_url',''), 200_000).decode('utf8', 'replace')
        needle = asset['name']
        digest = next((line.split()[0] for line in checks.splitlines() if len(line.split()) >= 2 and
                       line.split()[-1].lstrip('*').removeprefix('./') == needle), '')
        if not re.fullmatch('[0-9a-fA-F]{64}', digest):
            raise UpdateError('Release SHA256SUMS has no valid checksum for ' + needle)
        expected = digest
    actual = filehash(archive)
    if actual.lower() != expected.lower():
        raise UpdateError('Release ZIP SHA256 checksum mismatch. Installed shell was not changed.')
    return actual


def download_release(release, asset, dest):
    url = asset.get('browser_download_url','')
    if not url.startswith('https://github.com/thirteenalter/rusticq/releases/download/'):
        raise UpdateError('Release asset download is not under the official RusticQ repository.')
    curl = shutil.which('curl')
    if not curl:
        raise UpdateError('curl is missing')
    result = subprocess.run([curl, '--fail', '--silent', '--show-error', '--location',
        '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10', '--max-time', '240',
        '--max-filesize', str(MAX_ZIP), '--output', str(dest), url],
        capture_output=True, timeout=250)
    if result.returncode != 0:
        raise UpdateError('Download failed: ' + result.stderr.decode('utf8','replace')[:240])
    if not dest.is_file() or dest.stat().st_size > MAX_ZIP or dest.stat().st_size == 0:
        raise UpdateError('Downloaded release ZIP has invalid size.')
    if asset.get('size') and dest.stat().st_size != asset['size']:
        raise UpdateError('Downloaded release file size does not match release metadata.')
    return verify_checksum(dest, release, asset)


def preserve_preferences(stage, target):
    for name in PRESERVE:
        existing = target / name
        if existing.is_symlink():
            raise UpdateError('Installed user configuration is symlinked; refusing silent override: ' + name)
        if existing.is_file():
            if existing.stat().st_size > 10_000_000:
                raise UpdateError('User settings unexpectedly large: ' + name)
            target = stage / name
            if target.exists() or target.is_symlink():
                raise UpdateError('Update package tries to replace user settings: ' + name)
            shutil.copy2(existing, target)


def copy_dev_git(target, stage):
    original = target / '.git'
    if not original.exists() and not original.is_symlink():
        return
    if original.is_symlink():
        raise UpdateError('Refusing to overwrite development repo with symlinked .git.')
    dest = stage / '.git'
    if dest.exists() or dest.is_symlink():
        raise UpdateError('Release archive unexpectedly contains .git metadata.')
    if original.is_dir():
        count = [0]
        def limit(_path, names):
            count[0] += len(names)
            if count[0] > 12000:
                raise UpdateError('Git metadata too large for safe copy; use manual git pull instead.')
            return []
        shutil.copytree(original, dest, ignore=limit, symlinks=False)
    elif original.is_file():
        shutil.copy2(original, dest)
    else:
        raise UpdateError('Unsupported git metadata file.')


def stage_install(stage, source, tag, target='installed', checksum='', checksum_published=False):
    dest = assert_target(target)
    validate_tree(stage)
    preserve_preferences(stage, dest)
    if target == 'dev':
        copy_dev_git(dest, stage)
    backup = dest.parent / (dest.name + '-before-update-' + time.strftime('%Y%m%d-%H%M%S') + '-' + str(os.getpid()))
    if backup.exists() or backup.is_symlink() or dest.is_symlink():
        raise UpdateError('Unsafe update destination or backup collision.')
    dest.rename(backup)
    try:
        stage.rename(dest)
        validate_tree(dest)
        target_save(target, source=source, installed_tag=tag, update_available=False,
                   state='installed', progress=100, phase='Installed to ' + target,
                   changed=[str(dest)], backup=str(backup), last_update=int(time.time()),
                   checksum=checksum, checksum_published=checksum_published,
                   message=('Updated ' + str(dest) + '. Backup: ' + str(backup) +
                            '. Reboot/login or restart the active shell to load changes.'))
    except Exception:
        if dest.exists():
            broken = dest.parent / ('.failed-update-' + str(os.getpid()))
            dest.rename(broken)
            shutil.rmtree(broken)
        backup.rename(dest)
        raise
    return dict(ok=True, source=source, target=target, tag=tag, backup=str(backup),
                installed_path=str(dest), checksum=checksum,
                checksum_published=checksum_published, restart_required=True,
                message=state_read()['message'])


def download_release_source(release, asset, dest):
    url = asset.get('browser_download_url', '')
    allowed = 'https://api.github.com/repos/thirteenalter/rusticq/zipball/'
    if not url.startswith(allowed):
        raise UpdateError('Unexpected GitHub source archive URL')
    curl = shutil.which('curl')
    if not curl:
        raise UpdateError('curl is missing')
    result = subprocess.run([curl, '--fail', '--silent', '--show-error', '--location',
        '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10',
        '--max-time', '240', '--max-filesize', str(MAX_ZIP), '-H', 'User-Agent: RusticQ-Updater/2',
        '--output', str(dest), url], capture_output=True, timeout=250)
    if result.returncode or not dest.is_file() or not 0 < dest.stat().st_size <= MAX_ZIP:
        raise UpdateError('Official GitHub source archive download failed: ' + result.stderr.decode('utf8','replace')[:240])
    return filehash(dest)  # Auditing hash only; no independent checksum published.


def apply_update(source, confirm, tag='', target='installed'):
    if source not in ('local', 'github'):
        raise UpdateError('Unknown update source.')
    if target not in ('installed','dev'):
        raise UpdateError('Target must be dev or installed.')
    if source == 'local' and target == 'dev':
        raise UpdateError('Local source already IS ~/dev/quickshell. Use GitHub Update to refresh DEV.')
    expected = 'REAPPLY LOCAL' if source == 'local' else 'UPDATE SHELL'
    if confirm != expected:
        raise UpdateError('Type ' + expected + ' to authorize this update.')
    with exclusive():
        destination = assert_target(target)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.rusticq-update-', dir=destination.parent) as temp:
            workspace = Path(temp)
            stage = workspace / 'quickshell'
            if source == 'local':
                state_save(state='running', progress=15, phase='Validating local source')
                safe_copy_source(LOCAL, stage, destination)
                state_save(state='running', progress=70, phase='Local shell staged')
                return stage_install(stage, 'local', '', target)
            state_save(state='running', progress=7, phase='Checking GitHub Releases')
            release = releases_get(tag)
            asset = choose_full_asset(release)
            summary = release_summary(release)
            state_save(release=summary, checked_tag=summary['tag'], progress=18, phase='Downloading release ZIP')
            archive = workspace / 'release.zip'
            if asset.get('_source_archive'):
                digest = download_release_source(release, asset, archive)
                state_save(state='running', progress=55, phase='Source ZIP downloaded over HTTPS (no published SHA-256)', downloaded_sha256=digest)
                extract_full_zip(archive, stage, source_archive=True)
                published = False
            else:
                digest = download_release(release, asset, archive)
                state_save(state='running', progress=55, phase='GitHub ZIP SHA256 verified', downloaded_sha256=digest)
                extract_full_zip(archive, stage)
                published = True
            state_save(state='running', progress=82, phase='Validated shell ready to update ' + target)
            return stage_install(stage, 'github', summary['tag'], target, digest, published)


def rollback(confirm, target='installed'):
    if confirm != 'ROLLBACK SHELL':
        raise UpdateError('Type ROLLBACK SHELL to restore the previous version.')
    with exclusive():
        dest = assert_target(target)
        history = histories(target)
        if not history:
            raise UpdateError('No previous ' + target + ' shell backup exists.')
        previous = history[0]
        validate_tree(previous)
        preserve = dest.parent / (dest.name + '-before-update-' + time.strftime('%Y%m%d-%H%M%S') + '-rollback-' + str(os.getpid()))
        if preserve.exists() or preserve.is_symlink():
            raise UpdateError('Unsafe rollback destination.')
        dest.rename(preserve)
        try:
            previous.rename(dest)
            validate_tree(dest)
            for name in PRESERVE:
                src = preserve / name
                if src.is_symlink():
                    raise UpdateError('Unsafe personal settings symlink during rollback: ' + name)
                if src.is_file():
                    shutil.copy2(src, dest / name)
            if target == 'dev':
                # Protect most recently used .git metadata against accidental
                # loss even when restoring an earlier release snapshot.
                if not (dest / '.git').exists() and (preserve / '.git').exists():
                    copy_dev_git(preserve, dest)
            target_save(target, state='installed', progress=100, phase='Previous ' + target + ' shell restored',
                       source='rollback', installed_tag='', backup=str(preserve),
                       update_available=False, last_update=int(time.time()),
                       message='Previous ' + target + ' shell restored. Restart shell to activate.')
        except Exception:
            if dest.exists():
                dest.rename(previous)
            preserve.rename(dest)
            raise
        return dict(ok=True, target=target, backup=str(preserve), restored_from=str(previous),
                    restart_required=True, message='Previous ' + target + ' shell restored. Restart shell to activate.')


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['status','check','reapply-local','update-shell','rollback'])
    parser.add_argument('--tag', default='', help='Specific published GitHub Release tag, e.g. beta-1')
    parser.add_argument('--confirm', default='')
    parser.add_argument('--target', choices=['installed','dev'], default='installed')
    args = parser.parse_args()
    try:
        if args.command == 'status':
            emit(current_status())
        elif args.command == 'check':
            emit(check_updates(args.tag))
        elif args.command == 'reapply-local':
            emit(apply_update('local', args.confirm, target=args.target))
        elif args.command == 'update-shell':
            emit(apply_update('github', args.confirm, args.tag, args.target))
        elif args.command == 'rollback':
            emit(rollback(args.confirm, args.target))
    except (UpdateError, OSError, ValueError, zipfile.BadZipFile, subprocess.TimeoutExpired) as e:
        if args.command in ('reapply-local', 'update-shell'):
            # Report real errors; never claim success or delete prior backups.
            try: state_save(state='failed', progress=min(99, state_read().get('progress', 0)),
                            phase='Update failed', message=str(e)[:400])
            except OSError: pass
        emit(dict(ok=False, message=str(e)))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(run())
