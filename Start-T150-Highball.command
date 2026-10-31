#!/bin/bash
# Start the working, threaded T150 FFB bridge and open Highball.
set -u

if [[ -n "${T150_SOURCE_DIR:-}" ]]; then
    SRC="$T150_SOURCE_DIR"
elif [[ -x "$HOME/Desktop/T150-FFB/crossover-wheel/build/bin/t150d" ]]; then
    # Existing installation used in the original Highball test.
    SRC="$HOME/Desktop/T150-FFB/crossover-wheel"
else
    SRC="$HOME/Library/Application Support/t150-highball-ffb/crossover-wheel"
fi
BOOT="$SRC/build/bin/t150boot"
DAEMON="$SRC/build/bin/t150d"

die() {
    echo "ERROR: $*"
    if [[ -t 0 ]]; then read -r -p 'Press Enter to close...' _; fi
    exit 1
}

usb_has_product() {
    ioreg -p IOUSB -l -w0 | grep -q '"idProduct" = '"$1"
}

echo '=== T150 FFB + Highball ==='
[[ -x "$BOOT" && -x "$DAEMON" ]] || die "Missing t150boot / t150d in $SRC. Run setup-highball.sh first."
command -v ioreg >/dev/null 2>&1 || die 'ioreg not found; run on macOS.'

if pgrep -x t150d >/dev/null 2>&1; then
    echo 'A t150d process is already running. Not starting a second instance.'
    ps -axo pid=,command= | grep '[t]150d' || true
    die 'Stop the existing daemon (Ctrl+C), then run this launcher again.'
fi

if usb_has_product 46711; then
    echo 'T150 already in firmware mode (044f:b677).'
elif usb_has_product 46685; then
    echo 'Switching T150 from boot mode (044f:b65d)...'
    "$BOOT" || die 't150boot failed. Check USB, power and the PS3 selector.'
else
    die 'T150 not detected (expected USB 044f:b65d or 044f:b677). Check USB and PS3 mode.'
fi

ready=0
for ((i=0; i<25; i++)); do
    if usb_has_product 46711; then ready=1; break; fi
    sleep 1
done
[[ "$ready" -eq 1 ]] || die 'T150 did not switch to 044f:b677 within 25 seconds.'

echo 'T150 ready. Opening Highball...'
open -a Highball || die 'Highball could not be opened.'

echo 'Starting t150d -v -w (threaded macOS HID).'
echo 'Leave this Terminal window open while driving. Ctrl+C stops FFB.'
cd "$SRC" || die "Cannot access $SRC"
exec "$DAEMON" -v -w
