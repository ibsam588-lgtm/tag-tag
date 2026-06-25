# Tag Tag: Playground Blitz

Flutter Android arcade tag game set in a top-down playground arena.

## App Identity

- Play Store name: **Tag Tag: Playground Blitz**
- Launcher name: **Tag Tag**
- Android package: `com.tagtag.playgroundblitz`
- Privacy policy: `https://ibsam588-lgtm.github.io/tag-tag/privacy.html`

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

## GitHub Actions

- `.github/workflows/android.yml` runs Flutter analyze, tests, and release APK/AAB builds.
- `.github/workflows/deploy.yml` publishes `site/privacy.html` to GitHub Pages for the Play Store privacy policy URL.

## Play Store Prep

Play Store copy and release notes live in `play-store/`. Fastlane-compatible listing text lives in `fastlane/metadata/android/en-US/`.
