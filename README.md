# HSgram Native iOS

This is the new independent HSgram iOS client. It is intentionally separate from the Telegram-iOS fork and does not import TelegramCore, TelegramUI, Postbox, MtProtoKit, PremiumUI, or upstream Telegram assets.

## Product Goal

- Keep the submitted app identity as HSgram and continue targeting `com.hsgram.app`.
- Rebuild the iOS client as a native HSgram app with an App Store-safe binary profile.
- Match the existing HSgram iOS feature set 1:1, except voice calls and live streaming which are intentionally deferred.
- Use email-only registration and sign-in.
- Keep Android and PC interoperability by talking to HSgram server data through a native bridge that writes to the same backend state used by existing MTProto clients.
- Merge enterprise and premium capabilities into the default HSgram feature surface instead of maintaining separate iOS product tiers.

## Current State

The first scaffold builds the app shell, email-only auth flow, main tabs, chat thread UI, private-chat entry from contacts, supergroup creation, group chat actions, group management, channel listing/creation, circle tools, contacts, trust center, real settings screens, merged Advanced access, and a typed API client. New groups are always created as supergroups. The native bridge now starts in `interface.httpserver` for email auth, dialogs, message history, text sending and message actions, workspace summary, contacts, trust items, account profile, privacy summary, notification settings, storage summary, device reset, supergroup creation/member management/admin controls/invite links/admin logs, channel listing/creation, and merged premium/enterprise entitlements; the remaining 1:1 scope is tracked in `FULL_MIGRATION_MATRIX.md`.

## Build

Open `HSgramNative.xcodeproj` in Xcode and build the `HSgramNative` scheme, or run:

```sh
xcodebuild \
  -project HSgramNative.xcodeproj \
  -scheme HSgramNative \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```
