# Twenty-level expansion validation

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
