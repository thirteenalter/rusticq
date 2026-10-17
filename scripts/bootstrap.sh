#!/usr/bin/env bash
# Publish this script alongside the *full* ZIP. No default URL is fabricated.
# Refuse network installs without a sha256 digest supplied from a trusted release.
set -Eeuo pipefail
usage() {
  cat <<'HELP'
Usage: bash bootstrap.sh --url HTTPS_FULL_ZIP --sha256 64_HEX_DIGEST [--skip-deps]

Downloads a full RusticQ release over HTTPS, verifies its SHA-256 digest,
checks ZIP paths, then calls its user-local scripts/install.sh.
Publish this script and the ZIP to a real release before advertising curl.
RUSTICQ_RELEASE_URL and RUSTICQ_RELEASE_SHA256 may supply arguments.
HELP
}
URL="${RUSTICQ_RELEASE_URL:-}"
DIGEST="${RUSTICQ_RELEASE_SHA256:-}"
INSTALL_ARGS=()
while (( $# > 0 )); do
  case "$1" in
    --url) (( $# >= 2 )) || exit 2; URL="$2"; shift 2 ;;
    --sha256) (( $# >= 2 )) || exit 2; DIGEST="$2"; shift 2 ;;
    --skip-deps|--dry-run) INSTALL_ARGS+=("$1"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$URL" == https://* ]] || { echo 'An HTTPS release URL is required.' >&2; exit 2; }
[[ "$DIGEST" =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'A published 64-character SHA-256 checksum is required.' >&2; exit 2; }
for bin in curl sha256sum; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing bootstrap prerequisite: $bin" >&2; exit 1; }
done
if ! command -v python3 >/dev/null 2>&1; then
  command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 || {
    echo 'Python 3 is required to validate the release ZIP. Install python first.' >&2; exit 1;
  }
  echo 'Bootstrapping Python 3 for safe ZIP validation...'
  if command -v omarchy >/dev/null 2>&1; then
    omarchy update
    sudo pacman -S --needed -- python
  else
    sudo pacman -Syu --needed -- python
  fi
fi
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --max-time 120 "$URL" --output "$TMP/release.zip"
printf '%s  %s\n' "$DIGEST" "$TMP/release.zip" | sha256sum --check --status || { echo 'Checksum mismatch! Refusing to execute release.' >&2; exit 1; }
# Reject archive traversal, absolute paths, symlinks and ZIP bombs before extraction.
python3 - "$TMP/release.zip" "$TMP" <<'PY'
from pathlib import Path
import sys
import zipfile
archive, destination = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(archive) as z:
    members = z.infolist()
    if len(members) > 3000 or sum(i.file_size for i in members) > 150_000_000:
        raise SystemExit('Release archive exceeds safety limits')
    for member in members:
        path = Path(member.filename)
        if path.is_absolute() or '..' in path.parts or path.parts[0] != 'quickshell':
            raise SystemExit('Unsafe release path: ' + member.filename)
        if (member.external_attr >> 16) & 0o170000 == 0o120000:
            raise SystemExit('Symlink in release ZIP: ' + member.filename)
    if 'quickshell/scripts/install.sh' not in z.namelist() or 'quickshell/shell.qml' not in z.namelist():
        raise SystemExit('Not a complete RusticQ release')
    z.extractall(destination)
PY
bash "$TMP/quickshell/scripts/install.sh" "${INSTALL_ARGS[@]}"
