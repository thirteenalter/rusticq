#!/usr/bin/env python3
"""GUI-initiated, graphically authorized pacman transactions for RusticQ.

Never runs on page load. The GUI confirms the exact requested package.
Polkit authorizes the binary, never a user-writable privileged Python script.
No arbitrary commands, shell evaluation, or force-remove flags.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import sys
import urllib.request
import urllib.parse
import urllib.error
from concurrent.futures import ThreadPoolExecutor

PACKAGE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9@._+:-]{0,127}$")
DESKTOP = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._+-]{0,160}(?:\.desktop)?$")
# Always block destruction of core boot/session/package infrastructure from UI.
GUI_REMOVE_PROTECTED = frozenset({'pacman', 'glibc', 'systemd', 'systemd-libs',
                                  'hyprland', 'quickshell', 'linux', 'linux-lts'})


def run(args, timeout=10):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)


def validate_package(value):
    if not isinstance(value, str) or not PACKAGE.fullmatch(value):
        raise ValueError("Invalid package name")
    return value


def validate_request(action, package):
    if action not in ("install", "remove"):
        raise ValueError("Unsupported package operation")
    package = validate_package(package)
    if not shutil.which("pacman"):
        raise RuntimeError("pacman not available")
    if action == "remove":
        if package in GUI_REMOVE_PROTECTED:
            raise RuntimeError('Removing protected system/desktop components is disabled in RusticQ GUI.')
        result = run(["pacman", "-Qq", package])
        if result.returncode != 0 or result.stdout.strip() != package:
            raise RuntimeError("This package is not installed")
    else:
        result = run(["pacman", "-Si", package])
        if result.returncode != 0:
            raise RuntimeError("Package not found in configured pacman repositories. AUR/Flatpak/AppImage are not supported here.")
    return package


def resolve_desktop(entry_id, display_name='', search_dirs=None):
    """Find the owning pacman package for a real desktop file, never guess from an app label.

    Quickshell DesktopEntry.id can contain a basename, an XDG-style id or be
    empty for some application sources. A unique .desktop Name is a safe fallback
    only when the actual file is owned by exactly one pacman package.
    """
    import configparser
    if not isinstance(entry_id, str) or len(entry_id) > 260 or any(c in entry_id for c in ('/', '\x00', '\n', '\r')) or '..' in entry_id:
        raise ValueError('Invalid desktop entry ID')
    if not isinstance(display_name, str) or len(display_name) > 260:
        raise ValueError('Invalid application name')
    candidates = []
    filenames = [entry_id] if entry_id.endswith('.desktop') else [entry_id + '.desktop']
    filenames.append(entry_id.replace('/', '-') + '.desktop')
    if search_dirs is None:
        search_dirs = (Path('/usr/share/applications'), Path('/usr/local/share/applications'))
    for directory in search_dirs:
        directory = Path(directory)
        if not directory.is_dir():
            continue
        for path in directory.glob('*.desktop'):
            if path.is_symlink():
                continue
            if path.name in filenames:
                candidates.insert(0, path)
                continue
            if not display_name:
                continue
            try:
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.optionxform = str
                parser.read(path, encoding='utf-8')
                if parser.has_section('Desktop Entry') and parser.get('Desktop Entry', 'Name', fallback='').casefold() == display_name.casefold():
                    candidates.append(path)
            except (OSError, UnicodeError, configparser.Error):
                continue
    owners = set()
    for path in candidates:
        result = run(['pacman', '-Qqo', str(path)])
        if result.returncode == 0:
            for owner in result.stdout.splitlines():
                owner = owner.strip()
                if PACKAGE.fullmatch(owner):
                    owners.add(owner)
    if len(owners) == 1:
        return next(iter(owners))
    if len(owners) > 1:
        raise RuntimeError('Multiple pacman packages match this app. Search the exact package below instead.')
    for directory in (Path.home() / '.local/share/flatpak/exports/share/applications',
                      Path('/var/lib/flatpak/exports/share/applications')):
        for filename in filenames:
            if (directory / filename).is_file() and filename.endswith('.desktop'):
                app_id = filename[:-8]
                if FLATPAK_ID.fullmatch(app_id):
                    return dict(package=app_id, provider='flatpak')
    raise RuntimeError('No resolvable pacman/Flatpak owner. Search an AUR or Flatpak ID using the multi-source search.')


def make_commands(action, package, omarchy=None):
    validate_package(package)
    if action == 'remove':
        # -R preserves configurations and refuses breaking dependencies.
        return [['sudo', 'pacman', '-R', '--', package]]
    if action != 'install':
        raise ValueError('Unsupported action')
    if omarchy is None:
        omarchy = shutil.which('omarchy') is not None
    if omarchy:
        # Omarchy's own update hook controls snapshots/migrations.
        return [['omarchy', 'update'], ['sudo', 'pacman', '-S', '--', package]]
    # Arch prohibits partial upgrades: perform full sync+upgrade with install.
    return [['sudo', 'pacman', '-Syu', '--', package]]


def graphical_transaction(action, package):
    """Execute precisely one *validated* pacman transaction via graphical Polkit.

    pkexec runs /usr/bin/pacman directly, never a user-editable script as root.
    GUI gives explicit install/remove confirmation first; pacman runs without its
    own terminal prompts. Package hooks and dependency checks remain in force.
    """
    validate_request(action, package)
    pkexec = Path('/usr/bin/pkexec')
    pacman = Path('/usr/bin/pacman')
    if not (pkexec.is_file() and pacman.is_file()):
        raise RuntimeError('Graphical Polkit (pkexec) or system pacman is unavailable. Install a graphical polkit agent.')
    # GUI confirms the full transaction; pacman cannot prompt inside a GUI pipe.
    # Do not use -Rdd, -Sdd, --overwrite, --assume-installed, shell evaluation,
    # or a privileged invocation of Python from an editable checkout.
    if action == 'remove':
        cmd = [str(pkexec), '--disable-internal-agent', str(pacman), '-R', '--noconfirm', '--color', 'never', '--', package]
    elif shutil.which('omarchy') or Path('/usr/share/libalpm/hooks/00-omarchy-update-guard.hook').exists():
        # Let Omarchy's pacman hooks enforce its package-management policy.
        # Avoid direct full upgrade: Omarchy migration/update hooks own upgrades.
        cmd = [str(pkexec), '--disable-internal-agent', str(pacman), '-S', '--needed', '--noconfirm', '--color', 'never', '--', package]
    else:
        # Arch supports full upgrades, never an unsupported partial -Sy update.
        cmd = [str(pkexec), '--disable-internal-agent', str(pacman), '-Syu', '--needed', '--noconfirm', '--color', 'never', '--', package]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=45 * 60, check=False,
                                stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        raise RuntimeError('Package transaction timed out. Check pacman state before retrying.')
    details = ('\n'.join((result.stdout + '\n' + result.stderr).splitlines()[-16:])).strip()[-2000:]
    if result.returncode:
        return dict(ok=False, action=action, package=package,
                    message='Package operation failed or Polkit authorization was cancelled (exit ' + str(result.returncode) + '). ' + details)
    # Avoid success claims if a package hook reported success but no state changed.
    verify = run(['pacman', '-Qq', package])
    installed = verify.returncode == 0 and verify.stdout.strip() == package
    if installed != (action == 'install'):
        return dict(ok=False, action=action, package=package,
                    message='Pacman returned success but the installed package state did not match the request. ' + details)
    return dict(ok=True, action=action, package=package,
                message=('Installed ' if installed else 'Removed ') + package + ' successfully. ' + details)



# Beta 1: three searchable sources, one allowlisted transaction dispatcher.
# Searches are read-only and results are never executed without GUI confirmation.
SOURCES = ('pacman', 'yay', 'flatpak')
SEARCH_LIMIT = 18
SEARCH_QUERY = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9 ._+:-]{1,59}$")
FLATPAK_ID = re.compile(r"^[a-zA-Z][a-zA-Z0-9._-]{1,190}$")


def validate_source(source):
    if source not in SOURCES:
        raise ValueError('Unsupported source: choose pacman, yay or flatpak')
    return source


def validate_source_package(source, package):
    validate_source(source)
    if source == 'flatpak':
        if not isinstance(package, str) or not FLATPAK_ID.fullmatch(package) or '.' not in package:
            raise ValueError('Flatpak requires a valid application ID')
        return package
    return validate_package(package)


def cmd_output(command, timeout=20):
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=timeout, check=False,
                            stdin=subprocess.DEVNULL)
    return result


# Pacman, yay, and Flatpak have different human-readable CLI output formats.
# Do not treat terminal ANSI color or trimmed table columns as package IDs.
ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
REPO_HEADER = re.compile(r"^([a-zA-Z][a-zA-Z0-9+._-]*)/([^\s]+)\s+([^\s]+)(?:\s|$)")


def clean_output(value):
    return ANSI.sub('', value).replace('\r', '')


def parse_repo_results(text, source, limit=SEARCH_LIMIT):
    """Parse the exact two-line format emitted by pacman -Ss / yay -Ss.

    Header: extra/foo 1.0-1 [installed] OR aur/foo 1.0-1 (+2 0.01).
    Next indented line: description, not a second result.
    """
    found = []
    for line in clean_output(text).splitlines():
        if line[:1].isspace():
            if found and not found[-1]['description']:
                found[-1]['description'] = line.strip()[:230]
            continue
        match = REPO_HEADER.match(line.strip())
        if not match:
            continue
        repo, package, version = match.groups()
        if not PACKAGE.fullmatch(package):
            continue
        if source == 'yay' and repo.lower() != 'aur':
            continue
        if len(found) >= limit:
            break
        found.append(dict(source=source, name=package, title=package,
                          version=version, description='',
                          installed=bool(re.search(r"\[installed(?:[: ]|\])", line, re.I))))
    return found


def search_pacman(text, limit=SEARCH_LIMIT):
    result = cmd_output(['pacman', '-Ss', re.escape(text)], timeout=10)
    if result.returncode not in (0, 1):
        raise RuntimeError('pacman search: ' + result.stderr.strip()[-240:])
    return parse_repo_results(result.stdout, 'pacman', limit)


def search_yay(text, limit=SEARCH_LIMIT):
    if not shutil.which('yay'):
        return []
    # EXACT same command as a successful interactive terminal `yay -Ss <query>`.
    # --nocolor is not accepted consistently by every yay/Pacman combination;
    # handle escape codes in clean_output() instead.
    # Filter repository matches out in our parser to keep AUR results only.
    result = cmd_output(['yay', '-Ss', text], timeout=14)
    if result.returncode not in (0, 1):
        raise RuntimeError('yay search failed: ' + (result.stderr or result.stdout).strip()[-240:])
    return parse_repo_results(result.stdout, 'yay', limit)


def parse_flatpak_results(text, limit=SEARCH_LIMIT):
    """Read noninteractive Flatpak TSV. Ignore headers and invalid IDs.

    Every output column uses :full to prevent truncation with an ellipsis.
    """
    found = []
    for line in clean_output(text).splitlines():
        fields = [part.strip() for part in line.split('\t')]
        if len(fields) < 2:
            # Older Flatpak builds can use aligned spaces in piped output.
            fields = [part.strip() for part in re.split(r'\s{2,}', line.strip())]
        if len(fields) < 2:
            continue
        appid = fields[0]
        if not FLATPAK_ID.fullmatch(appid) or '.' not in appid or '…' in appid:
            continue
        title = fields[1] if len(fields) > 1 else appid
        desc = fields[2] if len(fields) > 2 else ''
        version = fields[3] if len(fields) > 3 else ''
        remote = fields[4] if len(fields) > 4 else ''
        found.append(dict(source='flatpak', name=appid, title=title or appid,
                          description=desc[:230], version=version,
                          remote=remote, installed=False))
        if len(found) >= limit:
            break
    return found


def flatpak_installed():
    if not shutil.which('flatpak'):
        return {}
    result = cmd_output(['flatpak', 'list', '--app', '--columns=application:full,installation'], timeout=4)
    installed = {}
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            parts = line.strip().split('\t')
            if len(parts) >= 2 and FLATPAK_ID.fullmatch(parts[0]):
                installed[parts[0]] = parts[1].strip()
    return installed


def flatpak_remotes():
    if not shutil.which('flatpak'):
        return {}
    result = cmd_output(['flatpak', 'remotes', '--columns=name,installation'], timeout=12)
    remotes = {}
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            fields = line.strip().split('\t')
            if len(fields) >= 2 and fields[0]:
                remotes[fields[0]] = fields[1].strip().lower()
    return remotes


def search_flatpak(text, limit=SEARCH_LIMIT):
    if not shutil.which('flatpak'):
        return []
    result = cmd_output(['flatpak', 'search', '--columns=application:full,name:full,description:full,version:full,remotes:full', text], timeout=8)
    if result.returncode not in (0, 1):
        raise RuntimeError('Flatpak search: ' + result.stderr.strip()[-240:])
    records = parse_flatpak_results(result.stdout, limit)
    # A slow Flatpak installation database must not discard valid search results.
    try:
        installed = flatpak_installed()
        for item in records:
            item['installed'] = item['name'] in installed
    except (OSError, subprocess.TimeoutExpired, RuntimeError):
        pass
    return records


def search_source(source, query):
    if source not in SOURCES:
        raise ValueError('Unsupported source: choose pacman, yay or flatpak')
    if not isinstance(query, str) or not SEARCH_QUERY.fullmatch(query.strip()):
        raise ValueError('Search for 2–60 letters/numbers (spaces allowed)')
    query = query.strip()
    available = {k: shutil.which(k) is not None for k in SOURCES}
    if not available[source]:
        return dict(ok=True, query=query, source=source, available=available, results=[], errors=[source + ': unavailable'])
    func = {'pacman': search_pacman, 'yay': search_yay, 'flatpak': search_flatpak}[source]
    try:
        return dict(ok=True, query=query, source=source, available=available, results=func(query), errors=[])
    except subprocess.TimeoutExpired:
        return dict(ok=True, query=query, source=source, available=available, results=[],
                    errors=[source + ': search timed out; check network/remote availability. Other providers remain usable.'])
    except (OSError, RuntimeError) as error:
        return dict(ok=True, query=query, source=source, available=available, results=[], errors=[source + ': ' + str(error)[:180]])

def search_sources(query):
    if not isinstance(query, str) or not SEARCH_QUERY.fullmatch(query.strip()):
        raise ValueError('Search for 2–60 letters/numbers (spaces allowed)')
    query = query.strip()
    available = {k: shutil.which(k) is not None for k in SOURCES}
    records, errors = [], []
    methods = [('pacman', search_pacman), ('yay', search_yay), ('flatpak', search_flatpak)]
    # Parallel only while a user requests a search; no persistent background indexer.
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [(source, pool.submit(func, query)) for source, func in methods if available[source]]
        for source, job in jobs:
            try:
                records.extend(job.result())
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
                errors.append(source + ': ' + str(error)[:180])
    return dict(ok=True, results=records, available=available, errors=errors)


def available_sources():
    return dict(ok=True, available={k: shutil.which(k) is not None for k in SOURCES})


def flatpak_location(package):
    installed = flatpak_installed()
    location = installed.get(package, '').lower()
    if 'user' in location:
        return '--user'
    if location:
        return '--system'
    remotes = flatpak_remotes()
    # Prefer user-local Flathub when available; system remotes can prompt Polkit.
    if 'flathub' in remotes:
        return '--user' if 'user' in remotes['flathub'] else '--system'
    if any('user' in scope for scope in remotes.values()):
        return '--user'
    if remotes:
        return '--system'
    raise RuntimeError('No Flatpak remotes configured. Add Flathub before using the GUI.')


def lookup_aur_package(package):
    """Verify exact AUR name via official HTTPS RPC, not yay's version-specific
    -Sia/--nocolor preflight (which can be forwarded to pacman incorrectly).
    The response is untrusted and is never treated as executable data.
    """
    validate_package(package)
    url = 'https://aur.archlinux.org/rpc/v5/info?' + urllib.parse.urlencode({'arg[]': package})
    request = urllib.request.Request(url, headers={'User-Agent': 'RusticQ-Package-Manager/1'})
    try:
        with urllib.request.urlopen(request, timeout=16) as response:
            blob = response.read(160_001)
        if len(blob) > 160_000:
            raise RuntimeError('AUR metadata response is unexpectedly large')
        data = json.loads(blob)
    except (urllib.error.URLError, TimeoutError, ValueError, UnicodeError) as exc:
        raise RuntimeError('Could not verify AUR package using official HTTPS RPC: ' + str(exc)[:200]) from exc
    found = data.get('results') if isinstance(data, dict) else None
    if not isinstance(found, list) or not any(isinstance(x, dict) and x.get('Name') == package for x in found):
        raise RuntimeError('AUR package does not exist: ' + package)
    return True


# Polkit is the credential owner. These probes do not create a second agent
# when an existing desktop authentication agent is already running.
AGENT_PROCESS_MARKERS = (
    'hyprpolkitagent', 'polkit-kde-authentication-agent',
    'polkit-gnome-authentication-agent', 'lxqt-policykit-agent',
    'mate-polkit', 'xfce-polkit',
)


def running_polkit_agent():
    # pgrep's -x truncated comm field is unreliable for long executable names.
    # Inspect only processes owned by this user; no privileges or D-Bus changes.
    proc = Path('/proc')
    if not proc.is_dir():
        return False
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            cmdline = (entry / 'cmdline').read_bytes().split(b'\0')
            if not cmdline or not cmdline[0]:
                continue
            executable = Path(os.fsdecode(cmdline[0])).name.lower()
            if any(marker in executable for marker in AGENT_PROCESS_MARKERS):
                return True
        except (OSError, ValueError, UnicodeError):
            continue
    return False


def agent_service_available():
    if not shutil.which('systemctl'):
        return False
    check = subprocess.run(['systemctl', '--user', 'show', '-p', 'LoadState', '--value', 'hyprpolkitagent.service'],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           text=True, timeout=4, check=False)
    return check.returncode == 0 and check.stdout.strip() == 'loaded'


def native_agent_bundled():
    """Native Polkit service is instantiated by RusticQ shell.qml.

    Existence is NOT proof of a live registration; actual pkexec must still
    succeed, and a failed request must never start a package transaction.
    """
    shell = Path(__file__).resolve().parents[1]
    try:
        return ('NativePolkitAgent {}' in (shell / 'shell.qml').read_text(encoding='utf-8')
                and (shell / 'modules/main/NativePolkitAgent.qml').is_file())
    except OSError:
        return False


def ensure_graphical_agent():
    """Do not infer Polkit registration from process names.

    Omarchy Quattro runs its agent inside omarchy-shell; RusticQ does the
    same. Neither is named hyprpolkitagent in /proc. Probe by performing the
    authorized pkexec transaction, which fails closed without a real agent.
    """
    if running_polkit_agent():
        return dict(agent_ready=True, agent_started=False, agent='external')
    if native_agent_bundled():
        return dict(agent_ready=False, agent_started=False, agent='rusticq-native',
                    message='RusticQ native Polkit agent included; awaiting actual pkexec/PAM result.')
    if agent_service_available():
        launch = subprocess.run(['systemctl', '--user', 'start', 'hyprpolkitagent.service'],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, timeout=9, check=False)
        if launch.returncode == 0:
            return dict(agent_ready=False, agent_started=True, agent='hyprpolkitagent',
                        message='Hyprland agent service start requested; awaiting actual pkexec result.')
        issue = clean_output(launch.stderr or launch.stdout).strip()[-280:]
        raise RuntimeError('Hyprland Polkit service failed to start: ' + issue)
    raise RuntimeError('No graphical Polkit agent bundled or known. On Omarchy Quattro, the agent belongs to omarchy-shell; '
                       'when replacing that shell, use RusticQ with NativePolkitAgent or run another supported system agent.')


def auth_capabilities():
    polkit = Path('/usr/bin/pkexec').is_file()
    try:
        fingerprint_possible = (shutil.which('fprintd-verify') is not None and
            Path('/etc/pam.d/polkit-1').is_file() and
            'pam_fprintd.so' in Path('/etc/pam.d/polkit-1').read_text(errors='replace'))
    except OSError:
        fingerprint_possible = False
    return dict(ok=True, pkexec=polkit, known_agent_detected=running_polkit_agent(),
                native_agent_bundled=native_agent_bundled(),
                agent_service_available=agent_service_available(),
                fingerprint_configured=fingerprint_possible,
                message='System Polkit agent performs password/fingerprint PAM authentication. RusticQ never reads credentials.')


def preauthorize_package(source, action, package):
    """Prompt immediately via native GUI instead of waiting for the AUR build.

    This only executes /usr/bin/true after Polkit approval; it cannot install,
    remove or elevate a user-controlled script. The actual pacman phase may
    request authorization AGAIN depending on Polkit's retention policy.
    """
    validate_source_package(source, package)
    if action not in ('install', 'remove'):
        raise ValueError('Unsupported package operation')
    if source == 'flatpak' and flatpak_location(package) == '--user':
        return dict(ok=True, authorized=True, message='User Flatpak does not require administrator authentication.')
    if not Path('/usr/bin/pkexec').is_file():
        raise RuntimeError('pkexec is not installed; graphical administrator authorization is unavailable.')
    agent = ensure_graphical_agent()
    result = subprocess.run(['/usr/bin/pkexec', '--disable-internal-agent', '/usr/bin/true'],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL,
                            text=True, timeout=150, check=False)
    if result.returncode != 0:
        message = clean_output(result.stderr + '\n' + result.stdout).strip()[-400:]
        if result.returncode == 126:
            raise RuntimeError('System authentication was cancelled. No package operation started.')
        raise RuntimeError('Graphical Polkit authorization failed (pkexec exit ' + str(result.returncode) + '): ' +
                           (message or 'No registered graphical agent answered the request.') +
                           '. RusticQ requires an active native Polkit agent (check `qs -p .` logs for polkit registration), '
                           'or a separate system agent. On Omarchy Quattro, the default agent stops when omarchy-shell is replaced.')
    return dict(ok=True, authorized=True, agent_started=agent['agent_started'], agent=agent.get('agent', 'system'),
                message='System Polkit approved. Continuing with the package operation.')


def source_transaction(source, action, package):
    if action not in ('install', 'remove'):
        raise ValueError('Unsupported package operation')
    validate_source_package(source, package)
    if source == 'pacman':
        return graphical_transaction(action, package)
    if source == 'yay':
        if not shutil.which('yay'):
            raise RuntimeError('yay is not installed')
        # Yay builds AUR software as an UNPRIVILEGED user; only pacman phases
        # elevate through pkexec. Never run yay itself with sudo/pkexec.
        if os.geteuid() == 0:
            raise RuntimeError('Never build AUR packages as root')
        if action == 'remove' and package in GUI_REMOVE_PROTECTED:
            raise RuntimeError('Protected core package')
        if action == 'install':
            # AUR metadata lookup is independent of yay CLI versions. Some
            # yay/pacman combinations reject legacy --nocolor forwarded by yay.
            lookup_aur_package(package)
            if not Path('/usr/bin/pkexec').is_file():
                raise RuntimeError('pkexec is unavailable. Install a graphical Polkit agent; never launch yay with sudo.')
            # Do not allow pkexec to fall back to a hidden /dev/tty prompt.
            # Official yay accepts --sudo <command>; no sudo-loop flag is needed.
            # Build/PKGBUILD phases stay unprivileged. Only pacman elevates via
            # the session Polkit agent, which performs password/fingerprint PAM.
            cmd = ['yay', '-S', '--aur', '--needed', '--noconfirm', '--answerclean', 'None',
                   '--answerdiff', 'None', '--answeredit', 'None', '--sudo', '/usr/bin/pkexec',
                   '--sudoflags', '--disable-internal-agent', '--', package]
        else:
            if cmd_output(['pacman', '-Qq', package], timeout=10).returncode:
                raise RuntimeError('AUR package not installed')
            # Removing an AUR package is performed by pacman directly; it is
            # registered in the same pacman database, not a second database.
            cmd = ['/usr/bin/pkexec', '--disable-internal-agent', '/usr/bin/pacman', '-R', '--noconfirm', '--', package]
        result = cmd_output(cmd, timeout=55 * 60)
        success = result.returncode == 0
        if not success and ('nocolor' in clean_output(result.stderr + result.stdout).lower()
                            or 'nosudoloop' in clean_output(result.stderr + result.stdout).lower()):
            raise RuntimeError('yay/pacman combination rejected an unsupported command option. Inspect `yay -Pg`, `yay --version` and custom yay settings. RusticQ did not pass nocolor or nosudoloop.')
        state = cmd_output(['pacman', '-Qq', package], timeout=10).returncode == 0
        success = success and state == (action == 'install')
    else:
        if not shutil.which('flatpak'):
            raise RuntimeError('Flatpak is not installed')
        location = flatpak_location(package)
        if action == 'install':
            # No shell and no privileged user-authored script; Flatpak uses its
            # own system helper/polkit for system remotes as needed.
            cmd = ['flatpak', 'install', location, '--noninteractive', '--assumeyes', 'flathub', package]
            if 'flathub' not in flatpak_remotes():
                remotes = flatpak_remotes()
                name = next((r for r,scope in remotes.items() if
                             ('user' in scope) == (location == '--user')), None)
                if not name:
                    raise RuntimeError('Flatpak remote not found for chosen installation')
                cmd[-2] = name
        else:
            if package not in flatpak_installed():
                raise RuntimeError('Flatpak application not installed')
            cmd = ['flatpak', 'uninstall', location, '--noninteractive', '--assumeyes', '--', package]
        result = cmd_output(cmd, timeout=55 * 60)
        state = package in flatpak_installed()
        success = result.returncode == 0 and state == (action == 'install')
    details = ('\n'.join(clean_output(result.stdout + '\n' + result.stderr).splitlines()[-12:]))[-1500:]
    return dict(ok=success, source=source, action=action, package=package,
                message=(('Installed ' if action=='install' else 'Removed ') + package + ' using ' + source + '.'
                         if success else 'Package operation failed; inspect output and provider authorization. ') + ' ' + details)


def main(argv):
    if len(argv) in (2, 3) and argv[0] == 'resolve-desktop':
        resolved = resolve_desktop(argv[1], argv[2] if len(argv) == 3 else '')
        return dict(ok=True, package=resolved['package'], provider=resolved['provider']) if isinstance(resolved, dict) else dict(ok=True, package=resolved, provider='pacman')
    if len(argv) == 1 and argv[0] == 'sources':
        return available_sources()
    if len(argv) == 1 and argv[0] == 'auth-capabilities':
        return auth_capabilities()
    if len(argv) == 4 and argv[0] == 'authorize':
        return preauthorize_package(argv[1], argv[2], argv[3])
    if len(argv) == 2 and argv[0] == 'search':
        return search_sources(argv[1])
    if len(argv) == 3 and argv[0] == 'search-source':
        return search_source(argv[1], argv[2])
    if len(argv) == 4 and argv[0] == 'gui':
        _, source, action, package = argv
        return source_transaction(source, action, package)
    if len(argv) != 3:
        raise ValueError('Expected operation and package')
    op, action, package = argv
    if op == 'gui':
        return graphical_transaction(action, package)
    if op == 'launch':
        raise ValueError('Terminal package launcher has been retired. Use gui operation.')
    if op == 'inspect':
        validate_request(action, package)
        return {'ok': True, 'package': package, 'action': action, 'omarchy': shutil.which('omarchy') is not None}
    raise ValueError('Unsupported request')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({'ok': False, 'message': str(exc)}))
        sys.exit(1)
