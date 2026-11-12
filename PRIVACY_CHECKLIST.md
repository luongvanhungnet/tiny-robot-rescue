# Google Play Privacy & Publishing Checklist

- [x] Offline-capable gameplay & atomic local saves (`ProgressSave` v2)
- [x] First-launch Privacy & Consent dialog (`ConsentManager`) + Settings Privacy Preferences & Policy summary
- [x] Privacy Policy HTML template created (`docs/privacy.html` — ready for GitHub Pages)
- [x] 3-attempt offline Free Hint fallback + idempotent Ad/Billing adapters
- [ ] Unique final package name (currently `com.tinyrobot.rescue`) & Play Store title availability verified
- [ ] Godot Android custom build + AdMob / Google Play Billing plugins enabled (see `PLAY_STORE_AND_TIKTOK_GUIDE.md`)
- [ ] Target API level 36+ configured in Gradle Android export preset
- [ ] Signed AAB generated via `android-release.yml` with protected keystore secrets
- [ ] Public Privacy Policy URL enabled on GitHub Pages and entered in Play Console
- [ ] Data safety form, Content rating, Ads declaration, and Target audience fields completed truthfully
- [ ] Closed testing (12 testers / 14 continuous days if required for new personal accounts) completed before production
