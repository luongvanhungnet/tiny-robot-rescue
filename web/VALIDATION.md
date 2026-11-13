# Visual hints and level 37 wind regression

Branch: `web/dev/codex`. Fetched and merged `origin/web/test/codex`; its head (`d2edf85`) is already an ancestor of the current history, so Git reported already up to date. The 50-level campaign remains in place.

Changes and evidence:

- Hint draws an animated cyan dashed example from each authored solution, with start/end markers and the written hint. It is nonphysical: ink, attempts, timers, and colliders are unaffected until the player draws. Guides support hide, retry/reset, loss recovery, navigation cleanup, and reduced motion.
- Reproduced level 37 with a valid right-backstop-only stroke: delivery succeeded, but cargo wind moved Pip off the platform at approximately **6.85 seconds** of a seven-second survival goal. Restricting that fan to `affects: ["cell"]` keeps Pip on the platform while preserving cargo behavior and the full survival requirement.
- `npm test`: **96 passed, 0 failed**, including all 50 reference solutions, guide geometry/animation, and the exact late-wind regression.
- `npx playwright test tests/browser/hint.spec.js tests/browser/game.spec.js`: **24 passed, 0 skipped** across desktop and emulated mobile. Tests verify visible guide state, no auto-play or resource consumption, actual mouse/touch drawing, reduced motion, hide/retry/navigation, lost-result recovery, and a full successful level-37 deadline with the alternate stroke.
- Production build, Capacitor asset sync, formatting, and `git diff --check` passed. The production offline test reloads without networking, opens the visual hint, and completes a player-drawn rescue.
- The rendered mobile example was visually inspected. Physical-device testing and a fresh full-campaign browser run were not performed for this change. Native APK compilation remains unverified.

No code was pushed or environment configuration published in this iteration.

---

# Grand Circuit: 50-level validation (historical)

Branch: `web/dev/codex`. The campaign contains exactly 50 sequential level IDs. Grand Circuit (41–50) adds ten distinct mechanic combinations while preserving prior level definitions, progress, and paint choices.

Current checks:

- `npm test`: **91 passed, 0 failed**. All 50 reference strokes win and ineffective strokes lose. New checks cover ten distinct mechanic signatures, pointer sampling variations, both cargo backstops, required robot lifts and shields, stacked receiver gate links, per-core inspection, two deliveries plus two robot arrivals in level 50, final badge persistence, and drawing-edge numeric tolerance.
- `CAMPAIGN_START_LEVEL=41 npm run test:e2e`: **17 passed, 1 intentionally skipped**. Levels 41–50 complete through real mouse drawing. Desktop/mobile touch and UI tests also cover old 10/20/30/36/40-level saves, paints, progression, pause/retry, settings, and viewport changes. Earlier levels are seeded as completed in this targeted campaign; a full 50-level browser run was not performed. The duplicate mobile campaign remains skipped.
- Production build, Capacitor sync, offline production reload and puzzle completion, formatting, and `git diff --check` passed.
- Robot lift and finale artwork were visually inspected at a phone viewport without rendering errors.
- Browser play caught an authored endpoint lying on the draw-zone boundary. The finale now leaves clearance for pointer quantization; a separate tiny epsilon handles floating-point noise without admitting genuinely outside strokes.

Native APK compilation, physical-device performance, and human difficulty/fairness certification remain unrun. This iteration did not push code or publish environment configuration.

---

# Relay Hub validation (historical)

Branch: `web/dev/codex`. Levels 37–40 bring the game to 40 puzzles. They add a strong-wind cargo cradle with laser protection, ordered upward inspection, dual-plane pulsing beams, and a cargo-linked gate/bridge exit. Existing level definitions are preserved.

Current checks:

- `npm test`: **73 passed, 0 failed**. All 40 reference solutions win and ineffective strokes lose. Relay tests also exercise small stroke variations, mandatory cradle/backstop pieces, inspection order and repeated visits, both beam planes and actual pulse timing, gate-channel isolation, and delivery plus robot-arrival requirements. Prior save, paint, and chapter regressions pass.
- `CAMPAIGN_START_LEVEL=37 npm run test:e2e`: **15 passed, 1 intentionally skipped**. The four new levels win through real mouse input. Desktop and emulated-mobile touch tests also cover a full cargo cradle stroke, migration from a completed level-36 save, prior chapter migrations, paints, progression, pause/retry, settings, and responsive layout. Earlier levels are seeded as completed for the targeted campaign; a full 40-level browser playthrough was not run. The duplicate mobile campaign remains skipped.
- Production build, Capacitor asset sync, offline production reload and puzzle completion, formatting, and `git diff --check` passed.
- Ordered ring markers and the linked cyan gate were visually inspected in a phone viewport without browser rendering errors.

Physical-device and human difficulty/fairness testing remain unrun. Native APK compilation remains unverified. This iteration did not push code or publish environment configuration.

---

# Power Lab validation (historical)

Branch: `web/dev/codex`. The campaign now has 36 levels. Power Lab (31–36) introduces nonlethal cargo, delivery objectives, wind forces, beam occlusion, matching docks, and per-core inspection stamps. The earlier 30 level definitions are preserved.

Current checks:

- `npm test`: **60 passed, 0 failed**. Reference solutions win and ineffective strokes lose on all 36 levels. New tests cover distinct mechanical requirements, no exact layout reuse, small stroke variations, mandatory wind, closest-surface laser occlusion, planning/warmup timing, idempotent cargo delivery, wrong-color rejection, per-core stamp ownership, and required survival after delivery.
- `CAMPAIGN_START_LEVEL=31 npm run test:e2e`: **13 passed, 1 intentionally skipped**. The six Power Lab puzzles win through real mouse input. Earlier levels are seeded as completed for this targeted run; a full 36-level browser playthrough was not run. Desktop and emulated-mobile tests also verify touch delivery, legacy 10/20/30-level saves, paints, progression, pause/retry, settings, and resizing. The duplicate mobile campaign is skipped.
- Production build, Capacitor sync, offline production reload and puzzle completion, formatting, and `git diff --check` passed.
- Fan fields, beam emitters, cargo docks, and the inspection ring were visually inspected in a phone viewport with no browser rendering errors.

Physical-device testing and human puzzle-balancing review remain unrun. Native APK compilation remains unverified. This iteration did not push code or publish environment configuration.

---

# Skyworks and earned paints validation (historical)

Branch: `web/dev/codex`. The game now contains 30 levels. Levels 21–30 introduce elevated bridges, two-robot charging runs, stepped shelters, reverse catchers, a paired-switch rescue, and a gated team finale. Four robot paints are available: Aqua by default, Copper after Workshop, Violet after Foundry, and Rose after Skyworks. Existing saves migrate without resetting progress or settings.

Current checks:

- `npm test`: **42 passed, 0 failed**. All 30 authored solutions win in real Matter.js; ineffective strokes lose on all 30. The ten new levels also pass small drawing variations. Save migration, multiple-robot objectives, paint unlock guards, selection, persistence, and the prior regressions pass.
- `CAMPAIGN_START_LEVEL=21 npm run test:e2e`: **11 passed, 1 intentionally skipped**. Levels 21–30 were completed through real mouse drawing. Levels 1–20 are seeded as previously completed in this targeted campaign fixture; a complete 30-level browser playthrough was not run in this iteration. The suite also verifies desktop and emulated-mobile touch, legacy saves, progression, earned paints, settings, pause, retry, and resizing. The duplicate mobile campaign remains skipped.
- Production build, Capacitor asset sync, offline production reload and puzzle completion, formatting, and `git diff --check` passed.
- Paint selection and the recolored robot were visually checked at a 320×568 phone viewport.

Native APK compilation and physical-device/Safari/Firefox testing remain unrun. The Godot edition is unchanged. No code was pushed or environment configuration published for this expansion.

---

# Twenty-level expansion validation (historical)

Branch: `web/dev/codex`. Levels 11–20 add crossing hazards, a raised shelter, three robots, two-gap bridges, reversed launches, paired switches, visible no-draw zones, and a two-robot switch finale. Existing ten-level saves retain stars/settings and unlock level 11 when level 10 was completed.

Current checks:

- `npm test`: **30 passed, 0 failed**, including real Matter.js solutions for all twenty levels, ineffective strokes that lose on all twenty, old-save migration, and small pointer-sampling variations in the finale.
- `npm run test:e2e`: **9 passed, 1 intentionally skipped**. The complete twenty-level campaign wins through real mouse drawing. Desktop and emulated-mobile touch tests validate the new cornered-stroke rescue, migration from an old completed save, progression, settings, retry, pause, and responsive layout. The duplicate mobile full-campaign test remains skipped.
- Final `npm run build`, `npx cap sync android`, `node tests/offline.mjs`, `npm run format:check`, and `git diff --check` passed. The built app reloads and completes a puzzle with networking disabled.
- The twenty-card selector was also checked at a phone-sized viewport, including scrolling to level 20 and opening the visibly marked no-draw puzzle.

Native APK compilation, physical-device performance, and human difficulty/fairness review were not run for this expansion. The original Godot project is unchanged. The earlier native build limitation below remains unresolved.

---

# Initial ten-level validation (historical, before first push)

Branch: `codex2`.

Passed on the current implementation:

- `npm test`: **18 passed, 0 failed**. All ten authored solution strokes win in the actual Matter.js engine; intentionally ineffective strokes lose on all ten levels. Geometry, planning/restart state, persistence/migration/corruption/storage-denied behavior, and unavailable monetization paths are exercised.
- `npm run test:e2e`: **7 passed, 1 intentionally skipped**. The complete ten-level campaign wins through real mouse drawing. Separate desktop and mobile Chromium tests cover first rescue, next-level unlock, persistence after reload, invalid strokes, pause/resume, immediate retry, settings, and viewport changes. Mobile first rescue uses CDP touch events. The duplicate full-campaign test is skipped in the mobile project; the full campaign runs on desktop.
- Production `npm run build` succeeded. Browser assets are in `web/dist/` and include the generated offline service worker.
- `node tests/offline.mjs` passed: production assets reload with browser networking disabled, and a drawn rescue completes successfully while offline.
- `npx cap sync android` succeeded and copied the built game into the native wrapper.
- `npm run format:check` and `git diff --check` passed.
- All Android manifest/resource XML files and all five workflow YAML files parsed. All 22 workflow shell steps passed `bash -n`.
- The preserved Godot 4.3 project imports from its new `android/` directory; its suite reports **150 passed, 0 failed**. Original tracked Godot file contents were compared with HEAD and are unchanged.

Not verified here:

- Native APK/AAB compilation. The cloud machine has Java 21 but no Android SDK or Android SDK variables. The initial Gradle wrapper request failed with `UnknownHostException: services.gradle.org`; retrying through the inherited Java proxy settings failed with `SSLHandshakeException: Remote host terminated the handshake`. TLS verification was kept enabled. No APK or AAB was produced locally. The new workflow installs the SDK on GitHub's runner, but has not been executed remotely in this task.
- Signed release builds require protected signing secrets. They were neither requested nor supplied during browser development.
- Physical Android/iOS browser testing, Safari/Firefox compatibility, long-session performance on a 2 GB device, human puzzle fairness review, and Play publication remain unrun. Chromium mobile emulation is not physical-device validation.

No code was pushed, no store upload occurred, and no environment configuration was published or reapplied.
