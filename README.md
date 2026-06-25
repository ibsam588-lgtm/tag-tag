# Tag Tag: Playground Blitz

Flutter Android arcade tag game set in a top-down playground arena.

## App Identity

- Play Store name: **Tag Tag: Playground Blitz**
- Launcher name: **Tag Tag**
- Android package: `com.tagtag.playgroundblitz`
- Privacy policy: `https://corsairlabs.com/tag-tag-playground-blitz-privacy-policy`

## Game Rules

- One player is **It** at a time.
- Tagging another player gives points and transfers **It**.
- Sprinting is tied to the joystick distance, so nonstop running drains stamina and slows players down.
- Dash is a timed burst with cooldown and stamina cost.
- Bell Zone events award points only to players who risk entering the glowing zone.
- The yard shrinks during the round to push everyone closer.
- If no tag happens for too long, **It** gets a catch-up boost.
- The final 15 seconds become Frenzy Mode with faster chases and score multipliers.

## Local Development

```bash
flutter pub get
flutter run -d emulator-5554
```

## Checks

```bash
flutter analyze
flutter test
```

## Android Builds

Build a release APK:

```bash
flutter build apk --release
```

Build a Play Store Android App Bundle:

```bash
flutter build appbundle --release
```

For Play Store upload signing, copy `android/keystore.properties.example` to `android/keystore.properties` and point it to your private upload key. Do not commit keystores or `keystore.properties`.

## AdMob Test IDs

Internal builds must use Google's AdMob demo IDs, not real production IDs:

- Android app ID: `ca-app-pub-3940256099942544~3347511713`
- Interstitial: `ca-app-pub-3940256099942544/1033173712`
- Rewarded: `ca-app-pub-3940256099942544/5224354917`
- Banner: `ca-app-pub-3940256099942544/9214589741`

The full set of Android demo IDs is kept in `lib/admob_test_ids.dart`.

## GitHub Actions

- `.github/workflows/android.yml` runs Flutter analyze, tests, and release APK/AAB builds.
- `.github/workflows/play-internal.yml` builds a signed Android App Bundle and uploads it to Google Play internal testing when the Play Console app and repository secrets are configured.
- `.github/workflows/deploy.yml` publishes `site/privacy.html` to GitHub Pages for the Play Store privacy policy URL.

## Play Store Prep

Play Store copy, form answers, and release steps live in `play-store/`. Fastlane-compatible listing text and changelogs live in `fastlane/metadata/android/en-US/`.
