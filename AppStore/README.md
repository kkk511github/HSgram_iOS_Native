# HSgram App Store Package

This folder tracks submission-facing material for the native HSgram iOS rebuild.

- `metadata/zh-Hans.md`: draft App Store copy and review notes.
- `screenshots/SHOT_LIST.md`: required screenshot coverage before submission.

Release gate:

- Build an archive from `HSgramNative.xcodeproj`.
- Verify AppIcon is present in `Assets.xcassets/AppIcon.appiconset`.
- Run source and binary scans for Telegram-derived module names and assets.
- Capture screenshots from the final UI using a HSgram review account.
- Confirm `Info.plist` permission strings and `PrivacyInfo.xcprivacy` match the shipped feature set.

