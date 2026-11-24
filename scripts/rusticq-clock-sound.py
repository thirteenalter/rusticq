#!/usr/bin/env python3
"""Play a local clock sound with stream gain; never change system volume."""
import argparse
import math
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import wave


class Cancelled(Exception):
    pass


def cancel(_signum, _frame):
    raise Cancelled()


def write_chime(path, sound='chime'):
    rate = 24000
    # A short three-note motif with a quiet gap, repeated for alarms.
    motif = bytearray()
    for n in range(rate * 2):
        t = n / rate
        note = int(t / .28)
        value = 0
        if note < 3:
            phase = t - note * .28
            envelope = min(1, phase / .012) * max(0, 1 - phase / .25) ** 2
            frequency = {'chime': (660, 880, 990), 'bell': (523, 659, 784), 'digital': (880, 880, 1175)}[sound][note]
            tone = math.sin(2 * math.pi * frequency * phase)
            if sound == 'bell':
                tone = .7 * tone + .3 * math.sin(2 * math.pi * frequency * 2.76 * phase)
            value = int(32767 * .5 * envelope * tone)
        motif.extend(struct.pack('<h', value))
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(motif)


def player_commands(path, volume):
    if type(volume) is not int or not 0 <= volume <= 125:
        raise ValueError('Clock volume must be between 0 and 125 percent')
    commands = []
    if player := shutil.which('pw-play'):
        # Keep the clock's selected gain when WirePlumber restores stream state.
        commands.append([player, '--volume', str(volume / 100), '--media-role', 'Notification',
                         '--properties', '{ application.name = "RusticQ Clock" media.name = "Clock alert" '
                         'state.restore-props = false channelmix.max-volume = 1.25 }', str(path)])
    if player := shutil.which('paplay'):
        commands.append([player, '--volume=' + str(round(65536 * volume / 100)),
                         '--client-name=RusticQ Clock', '--stream-name=Clock alert',
                         '--property=state.restore-props=false', str(path)])
    return commands


def play(sound, volume, loop, custom_file=''):
    if sound not in ('chime', 'bell', 'digital', 'custom'):
        raise ValueError('Unknown clock sound')
    if volume == 0:
        return
    if sound == 'custom':
        path = Path(custom_file)
        if not path.is_absolute() or path.suffix.lower() not in ('.wav', '.ogg', '.flac', '.mp3') or not path.is_file():
            raise RuntimeError('The selected sound file is unavailable. Choose another sound.')
    else:
        path = None
    players = player_commands(path or '', volume)
    if not players:
        raise RuntimeError('Clock sound needs pw-play or paplay. Visual alerts remain available.')
    with tempfile.TemporaryDirectory(prefix='rusticq-clock-sound-') as folder:
        if path is None:
            path = Path(folder) / 'chime.wav'
            write_chime(path, sound)
        commands = player_commands(path, volume)
        while True:
            for command in commands:
                try:
                    result = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL, timeout=300, check=False)
                    if result.returncode == 0:
                        break
                except (OSError, subprocess.TimeoutExpired):
                    continue
            else:
                raise RuntimeError('Unable to play clock sound. Check the audio output and system volume.')
            if not loop:
                return
            time.sleep(.15)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('timer', 'alarm'))
    parser.add_argument('--sound', choices=('chime', 'bell', 'digital', 'custom'), default='chime')
    parser.add_argument('--volume', type=int, default=125)
    parser.add_argument('--loop', action='store_true')
    parser.add_argument('--file', default='')
    args = parser.parse_args()
    if not 0 <= args.volume <= 125:
        parser.error('volume must be between 0 and 125 percent')
    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    try:
        play(args.sound, args.volume, args.loop, args.file)
    except Cancelled:
        return 0
    except (OSError, RuntimeError, ValueError) as exc:
        print(str(exc), flush=True)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
