# Play Store Release Checklist

## App Identity

- App name: `Tag Tag: Playground Blitz`
- Package name: `com.tagtag.playgroundblitz`
- Launcher name: `Tag Tag`
- Category: Game / Arcade
- Privacy policy URL: `https://corsairlabs.com/tag-tag-playground-blitz-privacy-policy`
- Public contact email: `labscorsair@gmail.com`
- Store listing copy: `play-store/store-listing.md`
- Data Safety draft: `play-store/data-safety.md`
- Console form draft answers: `play-store/console-form-answers.md`

## First-Time Play Console Setup

These steps must be done once in Google Play Console before the workflow can upload:

1. Create the app in Google Play Console.
2. Use app name `Tag Tag: Playground Blitz`.
3. Use default language `English (United States)`.
4. Select `Game` and category `Arcade`.
5. Select free pricing for the first internal test build.
6. Add the privacy policy URL.
7. Complete App content forms using `play-store/console-form-answers.md`.
8. Create an internal testing track and add tester email addresses or a tester group.
9. Upload the first signed `.aab` manually if Play Console has not accepted this package before.
10. Create a Google Play service account and grant it release/upload access to this app.
11. Download the service account JSON for GitHub Actions.

Helpful official docs:

- Google Play Developer Publishing API: https://developers.google.com/android-publisher
- Android app signing: https://developer.android.com/studio/publish/app-signing
- Fastlane Google Play upload action: https://docs.fastlane.tools/actions/upload_to_play_store/

## GitHub Secrets For Internal Testing Upload

Add these repository secrets in GitHub before running `.github/workflows/play-internal.yml`:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

To create `ANDROID_KEYSTORE_BASE64` from a local upload key on Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\upload-keystore.jks")) | Set-Clipboard
```

Use the same key alias and passwords that are stored in your local `android/keystore.properties`.

## Upload Key

Create a private upload key and keep it outside the repo. Do not commit the key or `android/keystore.properties`.

Local signing file format:

```properties
storeFile=C:/path/to/tag-tag-upload-key.jks
storePassword=change-me
keyAlias=tag-tag-upload
keyPassword=change-me
```

GitHub Actions writes its own temporary `android/keystore.properties` during the internal upload workflow.

## Internal Testing Workflow

Run the workflow manually from GitHub Actions:

1. Open `Actions`.
2. Select `Play Internal Testing`.
3. Click `Run workflow`.
4. Leave `release_status` as `completed` to publish to internal testers.
5. Use `draft` if you only want a Play Console draft.
6. Leave `build_number` blank unless you need a specific Android `versionCode`.

The workflow analyzes, tests, builds a signed `.aab`, and uploads it to the `internal` Play track. If this is the very first build for a brand-new Play Console app, upload the first signed `.aab` in Play Console manually, then use this workflow for the following internal builds.

## Before Production

- Add final app icon, feature graphic, phone screenshots, and tablet screenshots.
- Verify all form answers in `play-store/console-form-answers.md`.
- Confirm AdMob still uses Google demo/test IDs for internal testing.
- Install from the internal testing link and test launch, controls, rotation, sound, offline behavior, and store/tutorial screens.
- Increase `version` in `pubspec.yaml` before each future Play upload if needed.
- Promote to closed, open, or production testing only after internal testers approve the build.
