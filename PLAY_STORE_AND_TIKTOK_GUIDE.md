# Google Play Launch & TikTok Growth Playbook

## Part A: Enabling Production Ads (AdMob) & Google Play Billing (M7-M8)

The core game currently runs 100% offline with clean adapter boundaries:
- `scripts/ads_adapter.gd`
- `scripts/billing_adapter.gd`
- `scripts/consent_manager.gd`

To connect live monetization for Google Play release:
1. **Enable Android Custom Gradle Build**:
   - Install the official Godot 4.3 Android Build Template (`addons/` for `GodotAdMob` and `GodotGooglePlayBilling`).
   - In `export_presets.cfg`:
     - Set `gradle_build/use_gradle_build=true`
     - Set `gradle_build/export_format=1` (AAB for Play Store)
     - Set `gradle_build/min_sdk="24"` and `gradle_build/target_sdk="36"` (or current Play requirement)
     - Set `permissions/internet=true` and `permissions/access_network_state=true`
2. **Wire Adapter Hooks**:
   - In `ads_adapter.gd`, connect to `Engine.get_singleton("AdMob")` for test IDs first (`ca-app-pub-3940256099942544/...`), then switch to production Ad Unit IDs via CI secrets/build config.
   - In `billing_adapter.gd`, connect `Engine.get_singleton("GodotGooglePlayBilling")` to `startConnection()`, `purchase("remove_interstitial_ads")`, `acknowledgePurchase()`, and `queryPurchases("inapp")` calling `verify_and_grant_purchase()`.
3. **Generate Upload Keystore & CI Secrets**:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias tinyrobot -keyalg RSA -keysize 2048 -validity 10000
   base64 -w 0 release.keystore
   ```
   Add GitHub Repository Secrets:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_ALIAS`
   - `ANDROID_KEYSTORE_PASSWORD`
   Run workflow **Android Release AAB** (`.github/workflows/android-release.yml`).

---

## Part B: Google Play Store Submission Checklist
- **Privacy Policy URL**: Enable GitHub Pages on `/docs` (`https://luongvanhungnet.github.io/tiny-robot-rescue/privacy.html`).
- **Store Listing Copy**:
  - **Title**: Tiny Robot Rescue: Draw to Save
  - **Short Description**: Draw ONE clever line to shield, bridge, and save the tiny robots!
  - **Full Description**:
    Sketch one continuous line to protect adorable tiny robots from spinning gears, rogue Spark-Drones, bouncing boulders, wind tunnels, and lasers!
    - 60 handcrafted physics puzzles across 6 mechanical chapters
    - 100% playable offline — no forced energy timers
    - Multiple creative solutions per level: build shields, ramps, bridges, and bunkers
    - Unlock 6 original robot skins using earned Bolts or milestone clears!
- **Play Console Declarations**:
  - Complete **App Content -> Ads** (Contains ads: Yes when AdMob enabled).
  - Complete **Data safety** truthfully matching AdMob/Billing SDKs.
  - Complete **Closed Testing** (if required for new personal developer accounts: 12 testers opted in for 14 continuous days) before applying for Production.

---

## Part C: TikTok 9:16 Viral Content Playbook
Enable **Settings -> Clean Capture Mode (TikTok Clips)** in the game for crisp vertical recording!

### Clip Structure (8–12 seconds, 9:16 portrait)
- **0–2s (Hook)**: Show obvious danger + caption (`"99% fail Level 14 with 1 line"`, `"Wait for the drone swarm..."`).
- **2–4s (Draw)**: Slow intentional draw (or deliberately funny flawed line!).
- **4–8s (Physics Drama)**: Spark-Drones bouncing, gear launching off a ramp, laser blocked!
- **8–12s (Payoff)**: Robot panics (`!`) then celebrates (`RESCUED!`) or comedic zap (`OOPS!`).

### 15 Ready-to-Record Level Hooks
1. **Level 01**: "Tutorial looks easy... until you draw sideways."
2. **Level 05**: "Save TWO robots with ONE single stroke."
3. **Level 08**: "Don't block the gear—LAUNCH IT!"
4. **Level 12**: "I left a 1mm gap for the Spark-Drones..." (funny fail!)
5. **Level 14**: "Two drone vents. One line. Go."
6. **Level 16**: "Ink limit challenge! Can you seal it in 300 ink?"
7. **Level 24**: "Catching a flying robot mid-air over spikes."
8. **Level 31**: "Wait—drawn lines BLOCK WIND?!"
9. **Level 32**: "Deflecting a laser with one stroke."
10. **Level 38**: "Laser + Swarm = pure panic."
11. **Level 41**: "Opening the gate WITHOUT touching the switch."
12. **Level 44**: "Three robots. Three hazards. One line."
13. **Level 47**: "Trick-shot bank off the ceiling onto the switch!"
14. **Level 53**: "Moving ferry + laser + gate + bridge."
15. **Level 60**: "The Final Boss puzzle—1 stroke to rule them all."
