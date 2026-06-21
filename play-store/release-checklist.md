# Play Store Release Checklist

- Create the app in Google Play Console with app name `Tag Tag: Playground Blitz`.
- Package name: `com.tagtag.playgroundblitz`.
- App category: Game / Arcade.
- Add short description and full description from `play-store/store-listing.md`.
- Add privacy policy URL: `https://ibsam588-lgtm.github.io/tag-tag/privacy.html`.
- Complete Data Safety using `play-store/data-safety.md`.
- Complete content rating questionnaire.
- Add app icon, feature graphic, phone screenshots, and tablet screenshots.
- Create a private upload key and save local signing values in `android/keystore.properties`.
- Build a signed Android App Bundle (`.aab`) from the Android project with `npm run android:bundle`.
- Upload the `.aab` to internal testing first.
- Test install, launch, controls, rotation, audio, and offline behavior.
- Promote to closed/open testing or production after review.
