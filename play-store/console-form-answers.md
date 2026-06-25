# Google Play Console Form Answers

These answers match the current offline prototype build. Re-check before any release that adds ads, analytics, accounts, cloud saves, leaderboards, multiplayer, crash reporting, or purchases.

## Store Settings

- App category: Game
- Game category: Arcade
- Tags: Arcade, Casual, Action, Offline, Single player
- Free or paid: Free
- Contains ads: Yes, using Google AdMob demo/test IDs for internal testing.
- In-app products: No
- App access: All functionality is available without special access.

## Privacy And Data Safety

- Privacy policy URL: `https://corsairlabs.com/tag-tag-playground-blitz-privacy-policy`
- Collects or shares user data: Yes, when the planned Google Mobile Ads SDK / AdMob integration is included.
- Personal information collected: No
- Financial information collected: No
- Location collected: Approximate location, inferred by the ads SDK from IP address.
- Photos or videos collected: No
- Audio files collected: No
- Files or documents collected: No
- Calendar collected: No
- Contacts collected: No
- App activity collected: App interactions by the ads SDK.
- Web browsing collected: No
- App info and performance collected: Crash logs and diagnostics by the ads SDK.
- Device or other IDs collected: Device or other IDs by the ads SDK.
- Data shared with third parties: Yes, by the ads SDK.
- Users can request data deletion: Not applicable because the current app does not create accounts or collect server-side data.
- Data encrypted in transit: Yes.

## Content Rating Draft

- Violence: No realistic violence, graphic violence, blood, or gore.
- Fear: No horror, intense fear, or jump scares.
- Sexual content: No.
- Language: No profanity.
- Controlled substances: No.
- Gambling: No.
- User-generated content: No.
- User interaction: No online multiplayer, chat, messaging, or user profiles in the current build.
- Location sharing: No.
- Digital purchases: No.

## Target Audience

Recommended current setup:

- Target age groups: 13-15, 16-17, 18+
- Designed for Families program: No for the current build.
- Child-directed ads or ad SDKs: No child-directed ads. Internal builds use Google demo/test IDs.

Owner confirmation needed: the art style uses schoolyard and kid-like characters. If you want the app to target children under 13 or join Designed for Families, the release needs a separate child-safety review before submission.

## App Declarations

- News app: No.
- Government app: No.
- Health app: No.
- Financial features: No.
- COVID-19 contact tracing or status app: No.
- Ads ID usage: Yes, if Google Mobile Ads SDK / AdMob is included. Internal builds must use Google demo/test ad IDs until production monetization is approved.
- Sensitive permissions: No sensitive Android permissions are used in the current build.

## Release Notes

Use `fastlane/metadata/android/en-US/changelogs/default.txt` for internal testing release notes.
