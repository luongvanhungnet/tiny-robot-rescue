# PocketPuzzle (recovered Android game)

Standalone Godot game recovered from the USB-connected phone on 2026-11-14. This lives alongside `web/` and `android/` so it can be integrated separately later.

## Open and run

Use **Godot 4.7.2 stable**, then import `source/project.godot` in the project manager, or run:

```sh
godot --path source --editor
godot --path source
```

The game uses a 720 × 1280 portrait viewport. Game logic is in `source/game/`, interface scripts in `source/ui/`, and puzzle data in `source/assets/data/levels.json`.

## Recovery and limitations

- Installed application: `org.pocketpuzzle.prototype`, PocketPuzzle 0.9.0 (version code 9).
- Recovered with [GDRE Tools v2.7.4](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4).
- All 23 compiled GDScript files decompiled; all 28 imported resources converted, with two conversions reported as lossy. See `recovery/gdre_export.log`.
- This is recovered source: original comments, source formatting, development tests, CI, signing keys, and Android export presets are not recovered from the APK.
- The original APK is preserved locally at `recovery/original.apk` and ignored by Git. Its SHA-256 and app metadata are recorded in `recovery/apk-metadata.json`. Copy the APK separately if moving this recovery to another computer.
- Raw compiled-script backups and export metadata remain locally under `source/` and are ignored by Git. The editable project uses the recovered `.gd`, scene, and asset files.
- Device saves were not imported; the recovered game starts with its own local progress. The installed phone app was left intact.

## Validation

Godot 4.7.2 successfully imported the recovered project and ran its main scene headlessly for 120 frames without reported script or resource errors. Full gameplay, touch behavior, and rebuilding an Android package have not been verified.
