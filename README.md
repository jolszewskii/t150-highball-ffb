# T150 Force Feedback in Assetto Corsa on macOS (Highball)

Tested on Thrustmaster T150 RS Pro, MacBook M4 Pro, macOS 26 Tahoe, Highball/Wine 10 (`x64-sikarugir10.0_6-r28`) and Assetto Corsa 1.16.4 **without CSP**. Other configurations are unverified.

FFB, pedals and buttons worked. Tested at **70% gain / Skip FFB steps 0** without observed stuttering; not universal settings.

## Install in a new Highball bottle

1. Install Command Line Tools (`xcode-select --install`), [Homebrew](https://brew.sh/) and `brew install mingw-w64`.
2. Quit Assetto Corsa, Content Manager and the bottle. Download this repository, open Terminal in its directory and run:

   ```sh
   bash setup-highball.sh actry
   ```

   Replace `actry` with your bottle name. The script builds [crossover-wheel](https://github.com/renaudallard/crossover-wheel) at tested revision **`50ce00e`**, backs up the original DLL and installs `dinput8.dll` (proxy) plus `dinput8_orig.dll` (Wine original). It stops if `dinput8_orig.dll` already exists. No registry changes.
3. In **Highball → bottle → Advanced → DLL overrides**, add **`dinput8=n,b`** without deleting other entries. Tested: `version=n,b;winmm=n,b;dinput8=n,b`.
4. Set T150 to **PS3**, connect it, and run `Start-T150-Highball.command`. Wait for `wheel 044f:b677 open` and `backend macOS HID, threaded`. Keep Terminal open; start Assetto Corsa through Content Manager.

**Already working? Skip installation.** The launcher also detects `~/Desktop/T150-FFB/crossover-wheel`.

## Problems / recovery

- `044f:b65d`: boot mode. The launcher runs `t150boot` and waits for `044f:b677`.
- `no wheel at 044f:b65d`: harmless if `044f:b677` is present.
- Inputs work but FFB does not: check the DLL override, the bottle's `system32` DLLs, and whether `t150d` is running.
- `CPU OCCUPANCY > 99%`: try `t150d -v -w`; confirm `backend macOS HID, threaded`. Threading resolved stuttering in our test, but other causes are possible.
- Rollback: quit the game and run `bash setup-highball.sh restore actry`, then remove only `dinput8=n,b` from Highball overrides. Restores only backups made by this script.

No `sudo`, SIP change or kernel extensions. Based on [Renaud Allard’s crossover-wheel](https://github.com/renaudallard/crossover-wheel) (BSD-2-Clause). Upstream DLL binaries and Wine binaries are not redistributed.
