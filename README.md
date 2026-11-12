# Tiny Robot Rescue

**One-sentence pitch:** "Draw one clever line to shield, guide, or rescue a tiny robot from unpredictable machines."

## Features Implemented
- **60 Handcrafted Curated Levels** across 6 mechanical chapters (`data/levels/level_001.json` – `level_060.json`):
  1. **Ch 1 (01–10): Basic Training** — shields, deflectors, bridges, ramps, switches
  2. **Ch 2 (11–20): Drone Swarm & Bouncers** — homing **Spark-Drones**, heavy boulders, twin drone vents
  3. **Ch 3 (21–30): Skybridges & Spikes** — spike pits, **Spring Pads**, moving ferry platforms
  4. **Ch 4 (31–40): Wind & Lasers** — **Wind Fans** (blocked physically by drawn lines!) & **Lasers**
  5. **Ch 5 (41–50): Team Rescue & Gates** — multi-robot rescues, **Mechanical Gates**, switch-disarmed lasers
  6. **Ch 6 (51–60): Master Factory** — multi-hazard one-line finale puzzles
- **Juicy Physics & Feedback**:
  - Dual-outlined crisp drawn lines, danger trajectory telegraphs, Level 01 animated tutorial guide
  - Dynamic robot expressions (idle blinking, proximity panic `!`, victory happy) + **6 unlockable robot skins**
  - Collision spark bursts, victory confetti, failure highlight & screen shake (with Reduced Motion toggle)
  - Procedural SFX pool + lightweight looping background music + Android haptics
- **Offline-First & Monetization Ready**:
  - Atomic versioned saves (`schema_version = 2`) with v1 migration & `.bak` corruption recovery
  - First-launch Privacy & Consent prompt + Settings toggles (SFX, Music, Vibration, Reduced Motion, **Clean Capture Mode** for TikTok!)
  - Idempotent `AdsAdapter`, `BillingAdapter` (`remove_interstitial_ads`), and 3-attempt offline Free Hint fallback
- **Zero-Local-Install CI/CD**:
  - `.github/workflows/validate.yml`: headless import & unit/integration tests
  - `.github/workflows/android-debug.yml`: debug APK artifact
  - `.github/workflows/android-release.yml`: signed release AAB artifact

See [PLAY_STORE_AND_TIKTOK_GUIDE.md](PLAY_STORE_AND_TIKTOK_GUIDE.md) and [PRIVACY_CHECKLIST.md](PRIVACY_CHECKLIST.md) for production publishing and TikTok clip scripts.
