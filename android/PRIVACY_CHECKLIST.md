# Google Play Privacy & Publishing Checklist

- [ ] Unique package name (e.g., `com.yourstudio.tinyrobotrescue`) & title verified
- [ ] Target API level 36+ configured in Android export preset
- [ ] Signed AAB generated via `android-release.yml`
- [ ] Public Privacy Policy URL published and linked in-app (Settings) and Play Console
- [ ] Data safety form completed truthfully (offline local saves; disclose AdMob/Billing SDKs when enabled in M7)
- [ ] Content rating, Ads declaration, and Target audience fields completed
- [ ] Closed testing (12 testers / 14 days if required for new personal accounts) completed before production
