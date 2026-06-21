# Tag Tag: Playground Blitz

Top-down browser prototype for a playground tag game where the rules force action instead of letting runners kite forever.

## App Identity

- Play Store name: **Tag Tag: Playground Blitz**
- Launcher name: **Tag Tag**
- Android package: `com.tagtag.playgroundblitz`
- Privacy policy: `https://ibsam588-lgtm.github.io/tag-tag/privacy.html`

## Game Rules

- One player is **It**.
- Tagging another player gives points and transfers **It**.
- Sprinting and dashing drain stamina, so nonstop running becomes slower.
- Bell Zone events award points only to players who risk entering the highlighted zone.
- The yard shrinks during the round to push everyone closer.
- If no tag happens for too long, **It** gets a catch-up boost.
- The last 15 seconds become Frenzy Mode with faster tags and score multipliers.

## Local Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Android

```bash
npm run android:sync
```

Open the native project with:

```bash
npm run android:open
```

Build a release Android App Bundle with:

```bash
npm run android:bundle
```

For Play Store upload signing, copy `android/keystore.properties.example` to `android/keystore.properties` and point it to your private upload key. Do not commit keystores or `keystore.properties`.

## Deploy

This repo includes a GitHub Pages workflow in `.github/workflows/deploy.yml`. Pushing to `main` builds the app and deploys the `dist` folder through GitHub Pages.

## Play Store Prep

Play Store copy and release notes live in `play-store/`. Fastlane-compatible listing text lives in `fastlane/metadata/android/en-US/`.
