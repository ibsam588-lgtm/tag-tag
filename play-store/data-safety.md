# Google Play Data Safety Draft

Current planned release behavior:

- No account sign-in.
- Ads are planned.
- Assumed ads SDK: Google AdMob / Google Mobile Ads SDK.
- Internal testing must use Google-provided AdMob demo/test IDs only.
- No analytics SDK.
- No cloud saves.
- No multiplayer server.
- The game itself does not collect personal information.
- The ads SDK may collect and share data for ads, analytics, and fraud prevention.
- Game progress is session-only in the current build.

Suggested Play Console answers when AdMob is included:

- Data collected: Yes.
- Data shared: Yes, by the ads SDK.
- Data types: Approximate location, app interactions, diagnostics/crash logs, device or other IDs.
- Collection purposes: Advertising or marketing, analytics, fraud prevention, security, and compliance.
- Required collection: Yes, if ads are enabled for the release.
- Data encrypted in transit: Yes.
- Users can request data deletion: No account or developer-hosted personal data exists in the app; users can reset/delete Android advertising ID from Android settings and clear app storage.
- Delete data: Users can clear app storage from Android settings.
- Ads ID: Used when Google Mobile Ads SDK is included, unless the app is configured to disable Ad ID collection.
- Account deletion: Not applicable because the current build has no accounts.

Update this file before release if a non-AdMob ad network, analytics, accounts, online multiplayer, leaderboards, crash reporting, cloud saves, or purchases are added.
