#!/usr/bin/env bash
# RusticQ user-local source installation. Does NOT enable permanent Omarchy mode.
set -Eeuo pipefail
ORIGINAL_ARGS=("$@")

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-}")/.." && pwd -P)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DEST="$DATA_HOME/rusticq/source"
LAUNCHER="$HOME/.local/bin/rusticq"
SKIP_DEPS=0
DRY_RUN=0

usage() {
  cat <<'HELP'
Usage: bash scripts/install.sh [--dry-run] [--skip-deps] [--prefix DIRECTORY]

Install RusticQ as a separate user-local shell:
  ~/.local/share/rusticq/source   code, backup of previous install when upgrading
  ~/.local/bin/rusticq            launcher for `qs -p <installed source>`

Default: install missing core Arch packages with pacman (interactive sudo).
No Hyprland startup changes, Omarchy package changes, or service enabling.
Use Settings -> Integration separately for *confirmed* permanent replacement.

Options:
  --dry-run     Print plan only; change absolutely nothing
  --skip-deps   Never run pacman (for advanced users / offline setup)
  --prefix DIR  Put source under DIR (launcher still points to this location)
HELP
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-deps) SKIP_DEPS=1; shift ;;
    --prefix) (( $# >= 2 )) || { echo '--prefix needs a path' >&2; exit 2; }; DEST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# When piped from GitHub raw (`curl .../scripts/install.sh | bash`),
# Bash has no project tree. Fetch the complete repository over HTTPS then
# rerun the *same* local installer. Do not replace an Omarchy shell here.
if [[ ! -f "$ROOT/shell.qml" || ! -f "$ROOT/config/dependencies.json" ]]; then
  if (( DRY_RUN )); then
    echo 'REMOTE DRY RUN: would download RusticQ main branch and install user-local source; nothing changed.'
    exit 0
  fi
  [[ "$(id -u)" -ne 0 ]] || { echo 'Do not pipe installer as root' >&2; exit 1; }
  command -v curl >/dev/null 2>&1 || { echo 'Install curl to bootstrap RusticQ' >&2; exit 1; }
  if ! command -v python3 >/dev/null 2>&1; then
    [[ -e /etc/arch-release ]] && command -v sudo >/dev/null 2>&1 || { echo 'Python3 is required for safe archive verification' >&2; exit 1; }
    echo 'Installing Python to validate the release archive...'
    sudo pacman -S --needed -- python
  fi
  TEMP_SOURCE="$(mktemp -d)"
  trap 'rm -rf -- "$TEMP_SOURCE"' EXIT
  # main must contain this Beta 1 installer before using the README curl command.
  GITHUB_ARCHIVE='https://codeload.github.com/thirteenalter/rusticq/zip/refs/heads/main'
  echo 'Downloading RusticQ source from thirteenalter/rusticq main (HTTPS)...'
  curl --fail --location --silent --show-error --retry 2 --max-time 120 \
       --proto '=https' --proto-redir '=https' "$GITHUB_ARCHIVE" --output "$TEMP_SOURCE/rusticq.zip"
  if [[ -n "${RUSTICQ_ARCHIVE_SHA256:-}" ]]; then
    printf '%s  %s\n' "$RUSTICQ_ARCHIVE_SHA256" "$TEMP_SOURCE/rusticq.zip" | sha256sum -c --status || { echo 'SHA-256 mismatch' >&2; exit 1; }
  else
    echo 'NOTE: This installs the current main branch. Pin and verify a published release for reproducible installs.'
  fi
  python3 - "$TEMP_SOURCE/rusticq.zip" "$TEMP_SOURCE" <<'PY_CHECK'
from pathlib import Path
import sys, zipfile
archive, base = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(archive) as z:
    info = z.infolist()
    if len(info) > 4000 or sum(f.file_size for f in info) > 200_000_000:
        raise SystemExit('Source archive too large')
    for f in info:
        path = Path(f.filename)
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != 'rusticq-main':
            raise SystemExit('Unsafe archive path: ' + f.filename)
        if ((f.external_attr >> 16) & 0o170000) == 0o120000:
            raise SystemExit('Refusing symlink from archive')
    for required in ('rusticq-main/shell.qml','rusticq-main/scripts/install.sh','rusticq-main/config/dependencies.json'):
        if required not in z.namelist():
            raise SystemExit('Incomplete RusticQ GitHub archive: ' + required)
    z.extractall(base)
PY_CHECK
  bash "$TEMP_SOURCE/rusticq-main/scripts/install.sh" "${ORIGINAL_ARGS[@]}"
  exit $?
fi
[[ -f "$ROOT/shell.qml" && -f "$ROOT/config/dependencies.json" ]] || { echo 'Not a complete RusticQ source tree' >&2; exit 1; }
[[ "$DEST" = /* ]] || { echo '--prefix must be an absolute path' >&2; exit 2; }
[[ "$DEST" != / && "$DEST" != "$HOME" ]] || { echo 'Unsafe destination' >&2; exit 2; }
[[ ! -L "$DEST" && ! -L "$(dirname -- "$DEST")" ]] || { echo 'Refusing symlinked install target' >&2; exit 1; }
[[ ! -L "$LAUNCHER" ]] || { echo 'Refusing symlinked launcher' >&2; exit 1; }
if [[ -e "$LAUNCHER" ]] && ! grep -q '^# RusticQ managed launcher$' "$LAUNCHER"; then
  echo "Existing non-RusticQ executable at $LAUNCHER; refusing overwrite" >&2
  exit 1
fi
if [[ -d "$DEST" && ! -f "$DEST/shell.qml" ]]; then
  echo "Existing directory $DEST is not a RusticQ install. Refusing overwrite." >&2
  exit 1
fi

printf 'RusticQ installation plan\n  source: %s\n  target: %s\n  launcher: %s\n' "$ROOT" "$DEST" "$LAUNCHER"
if (( DRY_RUN )); then
  echo 'DRY RUN: no packages installed, no files written, no Omarchy startup changed.'
  exit 0
fi
[[ "$(id -u)" -ne 0 ]] || { echo 'Do not run as root; sudo is invoked only for packages.' >&2; exit 1; }

if (( ! SKIP_DEPS )); then
  command -v pacman >/dev/null 2>&1 || { echo 'Automatic dependency installation is Arch/pacman only. Use --skip-deps to install code only.' >&2; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo 'sudo not found; cannot install packages' >&2; exit 1; }
  [[ -e /etc/arch-release ]] || { echo 'Automatic package installation only supports Arch Linux and derivatives. Use --skip-deps.' >&2; exit 1; }
  # Python also reads the same dependency manifest used in Settings.
  if ! command -v python3 >/dev/null 2>&1; then
    echo 'Installing Python 3 to read the dependency manifest...'
    if command -v omarchy >/dev/null 2>&1; then
      omarchy update
      sudo pacman -S --needed -- python
    else
      sudo pacman -Syu --needed -- python
    fi
  fi
  missing_packages="$(python3 "$ROOT/scripts/rusticq-dependencies.py" missing-core)" || {
    echo 'Failed to inspect core packages; refusing to install an incomplete set.' >&2
    exit 1
  }
  MISSING=()
  if [[ -n "$missing_packages" ]]; then mapfile -t MISSING <<<"$missing_packages"; fi
  if (( ${#MISSING[@]} > 0 )); then
    printf 'Missing core packages: %s\n' "${MISSING[*]}"
    if command -v omarchy >/dev/null 2>&1; then
      echo 'Omarchy detected: using its update flow before adding packages.'
      omarchy update
      sudo pacman -S --needed -- "${MISSING[@]}"
    else
      sudo pacman -Syu --needed -- "${MISSING[@]}"
    fi
  else
    echo 'Core packages already installed.'
  fi
fi

# User-local, reversible versioned backup. No modifications to ~/.config/hypr.
PARENT="$(dirname -- "$DEST")"
mkdir -p -- "$PARENT" "$(dirname -- "$LAUNCHER")" "$STATE_HOME/rusticq/setup-backups"
STAGE="$(mktemp -d "$PARENT/.rusticq-stage.XXXXXXXX")"
BACKUP=''
cleanup() {
  local rc=$?
  if [[ -n "$STAGE" && -d "$STAGE" ]]; then rm -rf -- "$STAGE"; fi
  if (( rc != 0 )) && [[ -n "$BACKUP" && -d "$BACKUP" && ! -e "$DEST" ]]; then
    mv -- "$BACKUP" "$DEST" || true
  fi
}
trap cleanup EXIT
cp -a -- "$ROOT/." "$STAGE/"
find "$STAGE" -type d -name __pycache__ -prune -exec rm -rf -- {} +
find "$STAGE" -type f -name '*.pyc' -delete
[[ -f "$STAGE/shell.qml" ]] || { echo 'Staging failed' >&2; exit 1; }
if [[ -e "$DEST" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  BACKUP="$STATE_HOME/rusticq/setup-backups/source-$stamp"
  mv -- "$DEST" "$BACKUP"
  echo "Previous source backed up to: $BACKUP"
fi
mv -- "$STAGE" "$DEST"
STAGE=''
# Wrapper quoting is done with printf %q; the target is not executable shell input.
printf '#!/usr/bin/env bash\n# RusticQ managed launcher\nexec qs -p %q "$@"\n' "$DEST" > "$LAUNCHER"
chmod 755 "$LAUNCHER"
trap - EXIT
printf '\nRusticQ installed. Test with:\n  %s\n' "$LAUNCHER"
printf 'Or: qs -p %q\n' "$DEST"
printf 'Add ~/.local/bin to PATH if necessary. Permanent Omarchy replacement is OFF.\n'
