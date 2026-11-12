#!/usr/bin/env python3
"""Connect an explicitly requested hidden SSID without putting secrets in argv.

Input is one JSON line on stdin. NetworkManager owns the saved connection;
the activation password is passed through an anonymous in-memory descriptor.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import uuid


class WifiError(Exception):
    pass


def nm(*args, timeout=10, pass_fds=()):
    # Never forward nmcli output: errors may include credentials or user input.
    try:
        result = subprocess.run(
            ['nmcli', '--colors', 'no', '--wait', str(timeout), *args],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            timeout=timeout + 5, pass_fds=pass_fds,
            env={**os.environ, 'LC_ALL': 'C'},
        )
    except subprocess.TimeoutExpired:
        raise WifiError('Connection timed out. Check the SSID, security and password.') from None
    if result.returncode:
        messages = {
            3: 'Connection timed out. Check the SSID, security and password.',
            4: 'Could not connect. Check the SSID, security, password and signal.',
            8: 'NetworkManager is not running.',
        }
        raise WifiError(messages.get(result.returncode,
                        'NetworkManager request failed. Check Wi-Fi availability and connection permissions.'))
    return result.stdout.strip()


def validate(data):
    if not isinstance(data, dict):
        raise WifiError('Invalid hidden Wi-Fi request.')
    ssid = data.get('ssid', '')
    password = data.get('password', '')
    iface = data.get('interface', '')
    security = data.get('security', '')
    if not isinstance(ssid, str) or not 1 <= len(ssid.encode('utf-8')) <= 32 or any(c in ssid for c in '\0\r\n'):
        raise WifiError('Enter an SSID of 1–32 UTF-8 bytes without line breaks.')
    if not isinstance(iface, str) or not re.fullmatch(r'[a-zA-Z0-9_.:-]{1,40}', iface):
        raise WifiError('No valid Wi-Fi adapter selected.')
    if security not in ('wpa-psk', 'sae', 'open'):
        raise WifiError('Choose WPA/WPA2 Personal, WPA3 Personal or Open.')
    if not isinstance(password, str) or any(c in password for c in '\0\r\n'):
        raise WifiError('Wi-Fi passwords cannot contain line breaks.')
    if security == 'wpa-psk' and not (8 <= len(password.encode('utf-8')) <= 63
                                                   or re.fullmatch(r'[0-9a-fA-F]{64}', password)):
        raise WifiError('WPA/WPA2 needs 8–63 bytes or a 64-digit hexadecimal key.')
    if security == 'sae' and not 1 <= len(password.encode('utf-8')) <= 63:
        raise WifiError('WPA3 needs a password of 1–63 UTF-8 bytes.')
    return ssid, password if security != 'open' else '', iface, security


def connect_hidden(data):
    ssid, password, iface, security = validate(data)
    if not shutil.which('nmcli'):
        raise WifiError('NetworkManager nmcli is required to add hidden Wi-Fi.')
    if nm('-g', 'GENERAL.TYPE', 'device', 'show', iface) != 'wifi':
        raise WifiError('The selected Wi-Fi adapter is unavailable.')
    if nm('radio', 'wifi') != 'enabled':
        raise WifiError('Enable Wi-Fi before adding a hidden network.')

    uid = str(uuid.uuid4())
    secret_fd = None
    saved = False
    try:
        if password:
            secret_fd = os.memfd_create('rusticq-wifi-secret', os.MFD_CLOEXEC)
            with os.fdopen(os.dup(secret_fd), 'wb') as stream:
                stream.write(('802-11-wireless-security.psk:' + password + '\n').encode('utf-8'))
            os.lseek(secret_fd, 0, os.SEEK_SET)
        args = ['connection', 'add', 'save', 'no', 'type', 'wifi', 'ifname', iface,
                'con-name', ssid, 'connection.uuid', uid, 'ssid', ssid,
                '802-11-wireless.hidden', 'yes', 'connection.autoconnect', 'no']
        if security != 'open':
            args += ['802-11-wireless-security.key-mgmt', security,
                     '802-11-wireless-security.psk-flags', '0']
        nm(*args)
        activate = ['connection', 'up', 'uuid', uid, 'ifname', iface]
        if secret_fd is not None:
            activate += ['passwd-file', '/proc/self/fd/' + str(secret_fd)]
        nm(*activate, timeout=45, pass_fds=(secret_fd,) if secret_fd is not None else ())
        # A persistent modify saves the successful profile and NM-owned secrets.
        nm('connection', 'modify', 'uuid', uid, 'connection.autoconnect', 'yes')
        saved = True
        return {'ok': True, 'message': 'Connected to hidden Wi-Fi. Network saved.'}
    finally:
        if secret_fd is not None:
            os.close(secret_fd)
        if not saved:
            # Only this attempt's UUID is removed; existing profiles are untouched.
            try:
                nm('connection', 'delete', 'uuid', uid)
            except (OSError, WifiError):
                pass


def main():
    try:
        data = json.loads(sys.stdin.readline(8192))
        result = connect_hidden(data)
    except (ValueError, UnicodeError):
        result = {'ok': False, 'message': 'Invalid hidden Wi-Fi request.'}
    except WifiError as error:
        result = {'ok': False, 'message': str(error)}
    except OSError:
        result = {'ok': False, 'message': 'Could not run the hidden Wi-Fi connection helper.'}
    print(json.dumps(result), flush=True)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
