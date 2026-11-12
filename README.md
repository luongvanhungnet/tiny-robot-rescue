# Tiny Robot Rescue

**One-sentence pitch:** "Draw one clever line to shield, guide, or rescue a tiny robot from unpredictable machines."

## Vertical Slice (Levels 01–10)
- **Engine:** Godot 4.3 (GL Compatibility, Portrait 9:16 `720x1280`)
- **Offline-first:** 100% playable offline with local atomic JSON saves (`user://save_data.json`).
- **Cloud CI/CD:** GitHub Actions workflows for headless validation (`.github/workflows/validate.yml`), debug APK (`.github/workflows/android-debug.yml`), and signed release AAB (`.github/workflows/android-release.yml`).

## Zero-Local-Install Workflow
1. Push to GitHub to trigger `validate.yml` and `android-debug.yml`.
2. Download `tiny-robot-rescue-debug-apk` from the GitHub Actions run artifacts to test on a physical Android device.
3. For release AABs, configure `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, and `ANDROID_KEYSTORE_PASSWORD` in GitHub Repository Secrets, then trigger `android-release.yml`.
