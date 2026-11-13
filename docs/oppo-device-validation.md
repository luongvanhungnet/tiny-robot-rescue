# Oppo USB validation — 2026-11-14

Updated local `web/test/codex` by fast-forwarding from `origin/web/dev/codex` to `cac27eb` (100-level campaign). Existing PocketPuzzle recovery and README edits were preserved.

## Device and installed build

- Oppo CPH1803, Android 8.1.0, 720 × 1520 display.
- Chrome/WebView 101.0.4951.61.
- Debug APK built with Android Studio's Java 21 and Android SDK 36, then installed with `adb install -r` as `com.tinyrobot.rescue.web`.
- APK: `web/android/app/build/outputs/apk/debug/app-debug.apk` (ignored build output).

## Compatibility fixes found on the phone

1. Startup crashed because WebView 101 lacks `Array.toReversed()`. Replaced it with `slice().reverse()`, preserving the source array.
2. Unsupported `dvh` sizing left the game container at zero size, and unsupported `cqw` prevented UI scaling. Added `vh` dimensions as fallbacks and expressed UI measurements with a custom unit derived from the game's 9:16 viewport. Browsers supporting `dvh` retain dynamic viewport sizing.

## Results

- `npm test`: 253 passed, zero failures, including all 100 authored solution simulations.
- Production web build, Capacitor sync, and Gradle `assembleDebug` passed.
- Formatting checks for changed source files and `git diff --check` passed.
- On the physical phone's installed production web assets, touch-event strokes completed levels **1, 37, 51, 61, 71, 81, 91, and 100**. Level 100 displayed the campaign completion result.
- Backgrounding and reopening level 1 displayed the pause dialog; resuming and drawing completed the rescue.
- Hints were exercised on all sampled puzzles; machine help opened and closed on each sampled new chapter.
- Later locked puzzles were opened by a temporary DOM test setup, then solved through touch events. This does not verify normal progression through every preceding level.
- Existing saves were backed up locally and restored after testing. Verified the original 50 completed levels and paint selection; migration makes level 51 available. Test wins were not retained in the user's save.
- No fatal Android exception or Capacitor console error was found in the final inspected log segment.

Local screenshots, test scripts, save backup, build log, unit-test log, and the last batch's JSON results are in `web/test-results/oppo/` (ignored by Git). Screenshots cover wins for all eight sampled levels; JSON covers the final five-level batch.

This was targeted physical-device validation, not a complete 100-level phone playthrough, performance certification, or release-signing validation. No commit or push was made.
