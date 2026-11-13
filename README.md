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
npm test                 # actual Matter.js solutions for all 50 levels + game rules/saves
npm run build            # standalone browser files in dist/
npm run preview          # check the production build
npm run test:e2e         # desktop mouse + emulated mobile touch + full campaign with 50 puzzles
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

This is the specification's **browser campaign with 50 puzzles**, with original procedural artwork and sound, progression, stars, hints, settings, local saves, browser offline support, pause/background handling, and no ads or purchases. All 50 levels contain authored solution metadata exercised against the same Matter.js module used in the browser. Browser input tests exercise a complete campaign too. Progress is versioned and backed up; browsers provide atomic localStorage replacement rather than file renames. Storage denial leaves a playable memory-only session.

The 60-level expansion, native advertising/billing SDKs, production purchase verification, store publication, human solvability review, and physical Android performance/touch certification are later milestones. No simulated purchase button grants entitlements. See [web/RELEASE_CHECKLIST.md](web/RELEASE_CHECKLIST.md) for remaining device/release checks.

## Original Godot edition

```sh
cd android
godot --headless --import --quit
godot --headless --script res://tests/test_runner.gd
```

Use Godot **4.3**. The original GitHub workflows now run from `android/`; their APK/AAB artifact paths were adjusted to match the move.

## Skyworks and earned robot paints

Levels 21–30 add elevated bridges, two-robot charging objectives, stepped shelters, reverse catchers, and a gated team finale. Existing completed saves unlock the next chapter automatically. Settings → Robot paints lets you choose Aqua, Copper (complete Workshop), Violet (complete Foundry), or Rose (complete Skyworks). Paints are earned through play and saved locally.

The default browser campaign test plays all 50 levels. To target the new chapter while retaining desktop/mobile UI regressions, run `CAMPAIGN_START_LEVEL=21 npm run test:e2e` from `web/`; earlier levels are seeded as completed in that test fixture.

## Power Lab: six new mechanical puzzles

Levels 31–36 add energy-core deliveries, wind fields, polygon-occluded laser beams, color-matched docks, and per-core inspection stamps. This chapter has six distinct mechanical requirements; existing levels are preserved. Cores are safe cargo and use matching plus/triangle symbols as well as color. A core leaving the delivery area ends an impossible delivery promptly.

See [the content guide](web/CONTENT.md) for each puzzle's new interaction. Run `CAMPAIGN_START_LEVEL=31 npm run test:e2e` in `web/` to play the new chapter through real input and run the desktop/mobile UI regressions. The default campaign starts at level 1 and covers all 50 puzzles.

## Relay Hub (levels 37–40)

Four additional challenges combine strong crosswinds and laser shields, ordered inspections during an upward cargo flight, two pulsing beam planes, and a cargo-linked gate that requires a bridge to the charger. Existing levels remain intact. Inspection rings show one/two dots for their order; cargo gates use cyan to match the receiving dock.

Run `CAMPAIGN_START_LEVEL=37 npm run test:e2e` in `web/` to exercise the new chapter and existing desktop/mobile UI regressions. The default browser campaign covers all 50 levels.

## Grand Circuit (levels 41–50)

The campaign now reaches exactly **50 levels**. The final ten puzzles add opposing cargo currents, three-stage inspection, laser-protected bridges, parallel inspected airlocks, robot-carrying fans, elevated landings, stacked receiving bays, asymmetric inspection trays, a three-beam cargo vault, and a two-robot/two-parcel finale. Earlier level content, saved progress, and earned paints are retained.

From `web/`, run `CAMPAIGN_START_LEVEL=41 npm run test:e2e` for the targeted final-chapter playthrough and desktop/mobile regression suite. Default campaign testing still starts at level 1 and plays all 50 puzzles. Completing level 50 awards the Grand Circuit Hero badge.

## Example-line hints

Tap **Hint** to watch a cyan dashed example line appear alongside the written hint. It remains available for tracing and can be dismissed with **Hide example**. You still draw the physical stroke yourself; the preview uses no ink, attempts, or colliders. Reduced motion shows the complete guide immediately.

During simulation, **Retry + hint** starts a fresh planning attempt with the example. The loss-screen hint does the same. Submitting a valid line or leaving/restarting the level clears the guide.

Level 37's cargo fan now affects energy cores only. This fixes the late failure where wind could push Pip off the platform around 6.85 seconds despite successful delivery. Robot-lift fans in other levels retain their intended behavior.
