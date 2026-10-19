#!/usr/bin/env python3
"""Read-only Wi-Fi diagnostics, optional QR, explicit reversible DNS edits.

Never includes a Wi-Fi secret in stdout/JSON. QR PNG lives in a private 0700
runtime directory, is created only by direct request, and can be deleted.
"""
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

UUID = re.compile(r"\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\Z")
IFACE = re.compile(r"\A[a-zA-Z0-9_.:-]{1,40}\Z")


def nm(*args, timeout=4, check=True):
    p = subprocess.run(['nmcli', *args], capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
    if check and p.returncode:
        raise RuntimeError('NetworkManager request failed: ' + (p.stderr.strip() or 'check connection permissions')[:180])
    return p.stdout.strip()


def active_wifi():
    # UUIDs cannot contain nmcli's colon delimiter; DEVICE is validated.
    rows = nm('-t', '-f', 'UUID,TYPE,DEVICE', 'connection', 'show', '--active').splitlines()
    for row in rows:
        fields = row.rsplit(':', 2)
        if len(fields) != 3: continue
        uid, kind, iface = fields
        if kind in ('802-11-wireless', 'wifi') and UUID.fullmatch(uid) and IFACE.fullmatch(iface) and iface != '--':
            return uid, iface
    raise RuntimeError('No active Wi-Fi connection')


def value(uuid, field, secret=False):
    args = (['--show-secrets'] if secret else []) + ['-g', field, 'connection', 'show', 'uuid', uuid]
    return nm(*args)


def active_status():
    uid, iface = active_wifi()
    ssid = value(uid, '802-11-wireless.ssid') or 'Hidden SSID'
    ip4 = nm('-g', 'IP4.ADDRESS', 'device', 'show', iface, check=False)
    gateway = nm('-g', 'IP4.GATEWAY', 'device', 'show', iface, check=False)
    dns = nm('-g', 'IP4.DNS', 'device', 'show', iface, check=False).replace('\n', ', ')
    ipv6dns = nm('-g', 'IP6.DNS', 'device', 'show', iface, check=False).replace('\n', ', ')
    mode = value(uid, 'ipv4.method')
    custom_dns = value(uid, 'ipv4.dns')
    ignored_auto = value(uid, 'ipv4.ignore-auto-dns')
    base = Path('/sys/class/net') / iface / 'statistics'
    # No arbitrary paths: interface name is validated and resolved under sysfs.
    counters = {}
    for key in ('rx_bytes', 'tx_bytes'):
        try:
            path = (base / key).resolve(strict=True)
            if not str(path).startswith('/sys/'):
                raise RuntimeError('Unexpected counter path')
            counters[key] = int(path.read_text().strip())
        except (OSError, ValueError, RuntimeError):
            counters[key] = 0
    return {'ok': True, 'connected': True, 'ssid': ssid, 'interface': iface, 'uuid': uid,
            'ip4': ip4.splitlines()[0] if ip4 else '—', 'gateway': gateway or '—',
            'dns': dns or '—', 'dns6': ipv6dns or '—', 'ipv4Mode': mode,
            'customDns': custom_dns.replace('\n', ', '), 'manualDns': ignored_auto.lower() in ('yes', 'true'),
            'rxBytes': counters['rx_bytes'], 'txBytes': counters['tx_bytes']}


def qr_directory():
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR') or '')
    if not str(runtime).startswith('/') or not runtime.is_dir() or runtime.is_symlink():
        raise RuntimeError('Secure runtime directory unavailable')
    if runtime.stat().st_uid != os.getuid():
        raise RuntimeError('Runtime directory does not belong to this user')
    folder = runtime / 'rusticq-wifi-qr'
    if folder.is_symlink(): raise RuntimeError('Unexpected QR cache symlink')
    folder.mkdir(mode=0o700, exist_ok=True)
    if folder.stat().st_uid != os.getuid(): raise RuntimeError('QR cache ownership mismatch')
    folder.chmod(0o700)
    return folder


def qr_path():
    return qr_directory() / 'active-wifi.png'


def escape_wifi(text):
    return ''.join('\\' + c if c in ('\\', ';', ',', ':', '"') else c for c in text)


def make_qr():
    uid, _ = active_wifi()
    ssid = value(uid, '802-11-wireless.ssid')
    if not ssid: raise RuntimeError('Cannot share a hidden network with an unknown SSID')
    secure = value(uid, '802-11-wireless-security.key-mgmt').lower()
    if secure in ('', '--', 'none'):
        content = 'WIFI:T:nopass;S:' + escape_wifi(ssid) + ';;'
    elif secure in ('wpa-psk', 'sae', 'wpa-none'):
        password = value(uid, '802-11-wireless-security.psk', secret=True)
        if not password or password == '--':
            raise RuntimeError('NetworkManager has no saved Wi-Fi password for QR sharing')
        content = 'WIFI:T:WPA;S:' + escape_wifi(ssid) + ';P:' + escape_wifi(password) + ';;'
    else:
        raise RuntimeError('QR sharing supports WPA/WPA2/WPA3 personal or open networks, not enterprise authentication')
    folder = qr_directory()
    fd, temp = tempfile.mkstemp(dir=folder, prefix='.wifi-', suffix='.png')
    os.fchmod(fd, 0o600)
    os.close(fd)
    try:
        if shutil.which('qrencode'):
            proc = subprocess.run(['qrencode', '-l', 'M', '-s', '5', '-m', '2', '-t', 'PNG', '-o', temp],
                                  input=content, text=True, capture_output=True, timeout=6)
            if proc.returncode: raise RuntimeError('QR encoder failed')
        else:
            try:
                import qrcode
            except ImportError as exc:
                raise RuntimeError('Install qrencode (or python-qrcode) to enable secure Wi-Fi QR sharing') from exc
            qrcode.make(content).save(temp)
        os.replace(temp, qr_path())
        return {'ok': True, 'path': str(qr_path())}
    finally:
        if os.path.exists(temp): os.unlink(temp)


def clear_qr():
    qr_path().unlink(missing_ok=True)
    return {'ok': True, 'message': 'Wi-Fi QR cleared'}


def dns_change(operation, raw=''):
    uid, iface = active_wifi()
    if operation not in ('dns-auto', 'dns-manual'): raise ValueError('Invalid DNS operation')
    new_dns = []
    if operation == 'dns-manual':
        values = [v.strip() for v in raw.replace(',', ' ').split()]
        if not 1 <= len(values) <= 3: raise ValueError('Provide 1–3 IPv4 DNS server addresses')
        for v in values:
            address = ipaddress.ip_address(v)
            if address.version != 4: raise ValueError('Only IPv4 addresses are supported here')
            new_dns.append(str(address))
    previous_dns = value(uid, 'ipv4.dns')
    previous_ignore = value(uid, 'ipv4.ignore-auto-dns')
    if operation == 'dns-auto':
        nm('connection', 'modify', 'uuid', uid, 'ipv4.ignore-auto-dns', 'no', 'ipv4.dns', '')
    else:
        nm('connection', 'modify', 'uuid', uid, 'ipv4.dns', ' '.join(new_dns), 'ipv4.ignore-auto-dns', 'yes')
    try:
        nm('device', 'reapply', iface, timeout=10)
    except Exception:
        nm('connection', 'modify', 'uuid', uid, 'ipv4.dns', previous_dns, 'ipv4.ignore-auto-dns', previous_ignore, check=False)
        nm('device', 'reapply', iface, timeout=10, check=False)
        raise RuntimeError('DNS reapply failed; previous settings restored. Check NetworkManager permissions.')
    return {'ok': True, 'message': 'DNS switched to ' + ('automatic' if operation == 'dns-auto' else 'manual') + ' for this Wi-Fi connection'}


def main(args):
    # Cleanup must work even if NetworkManager is stopped or nmcli removed.
    if args == ['qr-clear']: return clear_qr()
    if not shutil.which('nmcli'): raise RuntimeError('NetworkManager nmcli is required')
    if args == ['status']: return active_status()
    if args == ['qr']: return make_qr()
    if args == ['dns-auto']: return dns_change('dns-auto')
    if len(args) == 2 and args[0] == 'dns-manual': return dns_change('dns-manual', args[1])
    raise ValueError('Unsupported Wi-Fi Advanced command')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])), flush=True)
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as e:
        print(json.dumps({'ok': False, 'message': str(e)}), flush=True)
        sys.exit(1)
