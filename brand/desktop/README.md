# Branded assets

Drop your own icons here. `scripts/prepare.sh` copies this directory over
`assets/desktop/` in the upstream tree after checkout, so anything you place
here wins.

If this directory is empty (other than this file), the build falls back to
the `stoatchat/assets` submodule — **upstream's real logos**. That is fine
for local testing and useless for redistribution: the AGPL covers the code,
not the artwork or the marks.

## Files the build expects

| Path | Used by |
|---|---|
| `icon.png` | tray icon and window icon (imported directly by `src/native/tray.ts`) |
| `icon.ico` | Windows Squirrel installer, `packagerConfig.icon` |
| `icon.icns` | macOS packaging |
| `hicolor/16x16.png` | Linux (flatpak/deb) |
| `hicolor/32x32.png` | " |
| `hicolor/64x64.png` | " |
| `hicolor/128x128.png` | " |
| `hicolor/256x256.png` | " |
| `hicolor/512x512.png` | " |

Match the upstream layout exactly — the overlay is a file copy, not a merge,
so a missing file falls through to upstream's rather than erroring.
