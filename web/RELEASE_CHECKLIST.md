# Vertical slice and release checks

The supplied design document is a product reference, not authorization to publish, contact third parties, or add commercial SDKs. This implementation adapts its core mechanics to Phaser 3, standalone Matter.js, and Capacitor at the user's request.

## Implemented

- 50 original authored layouts, starting with: First Shield, Side Impact, Bouncy Surprise, Narrow Shelter, Two Robots, Broken Bridge, Spring Launch, Gear Conveyor, Switch Rescue, One-Line Finale, followed by ten foundry puzzles with paired switches, three robots, multi-gap bridges, and crossing hazards, then ten Skyworks puzzles with elevated bridges, team charging objectives, and catching switches.
- Static single-stroke colliders, ink limits, finite coordinates, 96-point cap, touch simplification, robot/terrain exclusion, self-cross rejection, retry without consuming an invalid attempt.
- Fixed 60 Hz simulation with bounded catch-up and hazard velocity; collision categories and static sensors. Small hazards do not use true CCD; capped velocity and collider thickness must be checked on devices.
- Planning freezes physics; release starts the timer; pause and background suspend updates. Survival requires all robots to remain alive; exits require all robots at a charger; switch finale requires both switch activation and survival.
- Home, levels, gameplay, pause, results, settings, hints, stars, progression, chapter labels, workshop/foundry/skyworks badges, and four earned robot paints.
- Versioned local storage with sanitized load, previous-valid backup, atomic primary-key replacement, migration from earlier field names, and in-memory fallback when storage is denied. Pending partial data is never promoted.
- Optional procedural audio/music, reduced motion, Android haptics, safe-area padding, portrait native activity, responsive browser layout. No real advertising, analytics, payments, or personal-data collection.
- Production service worker caches the complete local app. First browser visit requires a connection; repeat visits work offline on HTTPS/localhost. Native packages bundle all core assets.
- Native target/compile API 36, unique package ID, debug workflow, protected-secret release signing workflow. No automatic publication.

## Before calling the slice device validated

- Human playtest all 50 puzzles without seeing solution metadata; refine fairness and discovery.
- Install the CI-generated debug APK on at least one physical Android device. Test touch cancel, fast input, interruptions, OS back, rotations, cutouts, gesture navigation, audio focus, low storage, and airplane mode.
- Test a 30+ minute session on a 2 GB device; measure frame time, memory, battery, and retry latency.
- Test desktop Chrome/Firefox/Safari and real mobile Chrome/Safari. Automated mobile coverage uses Chromium emulation, not a physical phone.
- Confirm APK signature, package ID, portrait orientation, API level, and permissions in CI artifacts.

## Before production

- Curate levels 51–60 after playtesting; there are 50 playable levels, not sixty.
- If monetization is later enabled, integrate official SDKs, explicit consent, real completed-reward callbacks, verified purchase/restore flows, and idempotency tests. Do not grant purchases from UI or arbitrary tokens. Existing adapters deliberately return unavailable.
- Review name availability, asset rights, accessibility, age rating, current Play target API and billing rules, public privacy-policy URL, Data safety, and ads/content declarations.
- Use protected signing secrets; retain the keystore securely. Update versionCode/versionName for every store build.
- Store publication requires separate explicit approval. No store upload occurs in these workflows.

Power Lab: six additional puzzles with distinct mechanic requirements are implemented and automatically checked for solutions, ineffective strokes, drawing variations, required wind effects, beam occlusion, cargo color validation, and per-core checkpoint ownership. Human difficulty/fairness review remains required.

Relay Hub: four additional levels validate ordered inspection routes, cargo-only lift fields, linked gate control, combined cargo/robot victory conditions, and real pulsing beam phases. The targeted mouse/touch suite and save migrations pass; physical-device and human difficulty testing remain outstanding.

Grand Circuit reaches exactly 50 levels. All 50 authored solutions and ineffective-stroke failures are checked in Matter.js. The final chapter is also played with real browser input, including the two-robot/two-delivery milestone and mobile continuation from an old level-40 save. Human difficulty review and physical-device validation remain outstanding.
