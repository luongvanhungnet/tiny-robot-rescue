# Tiny Robot Rescue

Draw one clever line to rescue Pip from a mischievous mechanical workshop.

- **[web/](web/)** — the new Phaser 3 + Matter.js game for desktop and mobile browsers, with a Capacitor Android wrapper in `web/android/`.
- **[android/](android/)** — the original Godot 4.3 Android game, preserved with its original source and tests.
- **[Specification](docs/game-specification.txt)** — supplied design reference. The requested Phaser/Matter/Capacitor stack takes precedence over its Godot-specific implementation sections.

## Play and develop the web edition

Node.js 22+ (24 also tested):

```sh
cd web
npm ci
npm run dev
```

Open the Vite address in a desktop or mobile browser. On a phone on the same network, use the development machine's network address. Production hosting must serve `web/dist/` at the origin root over HTTPS; localhost also supports offline caching.

Use the mouse or one finger to draw a continuous line, then release. Machines stay still while planning. Your fixed line becomes a Matter.js collider. Keep Pip safe, reach a charger, or activate a switch. Retry is always free. Keyboard: **R** retries, **Escape** pauses.

```sh
npm test                 # actual Matter.js solutions for all ten levels + game rules/saves
npm run build            # standalone browser files in dist/
npm run preview          # check the production build
npm run test:e2e         # desktop mouse + emulated mobile touch + full ten-level campaign
npm run test:offline     # production reload AND level completion with network disabled
```

Browser tests use `/usr/bin/chromium` by default; set `CHROMIUM_PATH` to your Chromium/Chrome executable. CI uses the runner's installed Chrome. `npm run format:check` checks source formatting.

## Android packaging of the web game

The old Godot project is `android/`; the **new native wrapper is `web/android/`**. Java 21, Android SDK platform 36, build-tools 36.0.0, and the SDK license agreements are required to compile the wrapper.

```sh
cd web
npm ci
npm run android:sync
npm run android:debug
# APK: android/app/build/outputs/apk/debug/app-debug.apk (relative to web/)
```

The **Web game Android packages** GitHub Actions workflow builds a debug APK. A manual `release` run produces a signed AAB using protected repository secrets `WEB_ANDROID_KEYSTORE_BASE64`, `WEB_ANDROID_KEYSTORE_ALIAS`, `WEB_ANDROID_KEYSTORE_PASSWORD`, and `WEB_ANDROID_KEY_PASSWORD`. It uploads artifacts only; it never publishes to Google Play. The new application ID is `com.tinyrobot.rescue.web`, so it can coexist with the Godot game. Recheck Play requirements before any submission.

## Scope and validation

This is the specification's **ten-level vertical slice**, with original procedural artwork and sound, progression, stars, hints, settings, local saves, browser offline support, pause/background handling, and no ads or purchases. All ten levels contain authored solution metadata exercised against the same Matter.js module used in the browser. Browser input tests exercise a complete campaign too. Progress is versioned and backed up; browsers provide atomic localStorage replacement rather than file renames. Storage denial leaves a playable memory-only session.

The 60-level expansion, native advertising/billing SDKs, production purchase verification, store publication, human solvability review, and physical Android performance/touch certification are later milestones. No simulated purchase button grants entitlements. See [web/RELEASE_CHECKLIST.md](web/RELEASE_CHECKLIST.md) for remaining device/release checks.

## Original Godot edition

```sh
cd android
godot --headless --import --quit
godot --headless --script res://tests/test_runner.gd
```

Use Godot **4.3**. The original GitHub workflows now run from `android/`; their APK/AAB artifact paths were adjusted to match the move.
