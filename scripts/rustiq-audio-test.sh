#!/usr/bin/env bash
# User-initiated, non-destructive, quiet speaker test. Never records the microphone.
set -Eeuo pipefail
command -v python3 >/dev/null || { echo 'Python 3 required' >&2; exit 1; }
player=''
if command -v pw-play >/dev/null; then player=pw-play
elif command -v aplay >/dev/null; then player=aplay
else echo 'Install pipewire (pw-play) or alsa-utils (aplay) for audio testing' >&2; exit 1
fi
tmp=$(mktemp --suffix=.wav)
trap 'rm -f -- "$tmp"' EXIT
python3 - "$tmp" <<'PY_WAV'
import math, struct, sys, wave
sample_rate=48000
with wave.open(sys.argv[1], 'wb') as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(sample_rate)
    duration=.48
    pcm=bytearray()
    for n in range(int(sample_rate*duration)):
        t=n/sample_rate
        edge=min(1.,n/1200, (sample_rate*duration-n)/1200)
        freq=440 if t < .23 else 660
        v=int(32767*.12*max(0.,edge)*math.sin(t*2*math.pi*freq))
        pcm.extend(struct.pack('<h',v))
    f.writeframes(pcm)
PY_WAV
"$player" "$tmp"
