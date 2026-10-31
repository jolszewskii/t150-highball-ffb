#!/bin/bash
# Highball-specific install/rollback for renaudallard/crossover-wheel.
# Intentionally does not edit Highball's GUI overrides or Wine's registry.
set -euo pipefail

usage() {
    echo 'Usage: bash setup-highball.sh [BOTTLE_NAME]'
    echo '       bash setup-highball.sh restore [BOTTLE_NAME]'
    echo 'Optional: HIGHBALL_ENGINE=engine-name, HIGHBALL_ROOT=path, T150_SOURCE_DIR=path'
}

die() { echo "ERROR: $*" >&2; exit 1; }

ACTION=install
if [[ "${1:-}" == 'restore' ]]; then ACTION=restore; shift; fi
if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then usage; exit 0; fi
[[ $# -le 1 ]] || { usage; exit 2; }
BOTTLE="${1:-actry}"
[[ "$BOTTLE" != */* && "$BOTTLE" != '.' && "$BOTTLE" != '..' && -n "$BOTTLE" ]] || die 'Invalid bottle name.'

[[ "$(uname -s)" == 'Darwin' ]] || die 'This installer runs on macOS only.'
# Homebrew is usually outside the PATH of some macOS Terminal sessions.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

HIGHBALL_ROOT="${HIGHBALL_ROOT:-$HOME/Library/Application Support/Highball}"
ENGINE="${HIGHBALL_ENGINE:-x64-sikarugir10.0_6-r28}"
SYS32="$HIGHBALL_ROOT/bottles/$BOTTLE/drive_c/windows/system32"
ENGINE_DLL="$HIGHBALL_ROOT/engines/$ENGINE/engine/lib/wine/x86_64-windows/dinput8.dll"
STATE_ROOT="$HOME/Library/Application Support/t150-highball-ffb/backups/$BOTTLE"
ACTIVE="$STATE_ROOT/original"

[[ -d "$SYS32" ]] || die "Bottle system32 not found: $SYS32"
if pgrep -x t150d >/dev/null 2>&1; then
    die 't150d is running. Stop the game and daemon before changing DLLs.'
fi

if [[ "$ACTION" == 'restore' ]]; then
    [[ -d "$ACTIVE" ]] || die "No backup from this installer: $ACTIVE"
    echo "Restoring DLLs in bottle '$BOTTLE'..."
    for name in dinput8.dll dinput8_orig.dll; do
        if [[ -f "$ACTIVE/$name" ]]; then
            cp -p "$ACTIVE/$name" "$SYS32/$name"
        elif [[ -f "$ACTIVE/$name.absent" ]]; then
            rm -f "$SYS32/$name"
        else
            die "Incomplete backup: $name"
        fi
    done
    mv "$ACTIVE" "$STATE_ROOT/restored-$(date +%Y%m%d-%H%M%S)"
    echo 'DLLs restored. Remove only dinput8=n,b from Highball DLL overrides.'
    exit 0
fi

[[ -f "$ENGINE_DLL" ]] || die "Wine DLL not found: $ENGINE_DLL (set HIGHBALL_ENGINE)."
[[ ! -e "$SYS32/dinput8_orig.dll" ]] || die 'dinput8_orig.dll already exists; possible prior installation. No files changed.'
[[ ! -e "$ACTIVE" ]] || die "An active backup already exists: $ACTIVE. Restore first; no files changed."
for cmd in git make clang x86_64-w64-mingw32-gcc; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing $cmd. Install Xcode Command Line Tools and/or: brew install mingw-w64"
done

# Tested revision, deliberately not a moving main branch.
REV='50ce00e'
DEFAULT_SRC="$HOME/Library/Application Support/t150-highball-ffb/crossover-wheel"
SRC="${T150_SOURCE_DIR:-$DEFAULT_SRC}"
if [[ ! -d "$SRC/.git" ]]; then
    [[ ! -e "$SRC" ]] || die "Source path exists but is not a Git checkout: $SRC"
    mkdir -p "$(dirname "$SRC")"
    echo "Cloning crossover-wheel into $SRC..."
    git clone https://github.com/renaudallard/crossover-wheel.git "$SRC"
    git -C "$SRC" checkout --detach "$REV"
else
    echo "Using existing checkout: $SRC (not changing its revision)."
fi

echo 'Building t150boot, t150d and the x64 DirectInput proxy...'
make -C "$SRC" tools daemon dll
PROXY="$SRC/build/bin/t150-dinput8.dll"
[[ -s "$PROXY" && -x "$SRC/build/bin/t150boot" && -x "$SRC/build/bin/t150d" ]] || die 'Build did not produce the expected files.'
file "$PROXY" | grep -q 'PE32+' || die 'Proxy is not a 64-bit Windows DLL.'

# Keep first-install originals outside the bottle; never overwrite these backups.
mkdir -p "$STATE_ROOT"
TMP_BACKUP="$STATE_ROOT/.original.tmp.$$"
mkdir "$TMP_BACKUP"
TMP_ORIG="$SYS32/.dinput8_orig.t150.$$"
TMP_PROXY="$SYS32/.dinput8.t150.$$"
cleanup() { rm -f "$TMP_ORIG" "$TMP_PROXY"; rm -rf "$TMP_BACKUP"; }
trap cleanup EXIT
for name in dinput8.dll dinput8_orig.dll; do
    if [[ -f "$SYS32/$name" ]]; then
        cp -p "$SYS32/$name" "$TMP_BACKUP/$name"
    elif [[ ! -e "$SYS32/$name" ]]; then
        : > "$TMP_BACKUP/$name.absent"
    else
        die "Unexpected file type at $SYS32/$name"
    fi
done
mv "$TMP_BACKUP" "$ACTIVE"
# Stage both DLLs in the destination filesystem before replacing either.
cp "$ENGINE_DLL" "$TMP_ORIG"
cp "$PROXY" "$TMP_PROXY"
mv -f "$TMP_ORIG" "$SYS32/dinput8_orig.dll"
mv -f "$TMP_PROXY" "$SYS32/dinput8.dll"
cmp -s "$ENGINE_DLL" "$SYS32/dinput8_orig.dll" || die 'Wine original DLL verification failed.'
cmp -s "$PROXY" "$SYS32/dinput8.dll" || die 'Proxy DLL verification failed.'

echo
printf 'Installed into: %s\n' "$SYS32"
printf 'Rollback backup: %s\n' "$ACTIVE"
echo 'NEXT: In Highball > bottle > Advanced > DLL overrides, add dinput8=n,b.'
echo 'Then run Start-T150-Highball.command (T150 switch: PS3).'
