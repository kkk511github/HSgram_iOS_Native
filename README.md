# HSgram Native iOS

This is the new HSgram iOS native client. The SwiftUI app shell and UI live outside the Telegram-iOS fork and do not use TelegramUI, Postbox, PremiumUI, or upstream Telegram visual assets.

Important App Store hardening note: the default native target now builds without legacy bridge files, optional Telegram/MtProtoKit bridge branches, or Telegram-derived linker/search settings. The native bundle now includes HSgram-owned AppIcon and AccentColor assets plus App Store metadata and screenshot-planning scaffolds. Keep running archive-time binary scans before submission, and capture final product screenshots with the review account before upload.

## Product Goal

- Keep the submitted app identity as HSgram and continue targeting `com.hsgram.app`.
- Rebuild the iOS client as a native HSgram app with an App Store-safe binary profile.
- Match the existing HSgram iOS feature set 1:1, except voice calls and live streaming which are intentionally deferred.
- Use email-only registration and sign-in.
- Keep Android and PC interoperability by talking to the existing HSgram server protocol and backend state used by Android, PC, and the old HSgram iOS client.
- Merge enterprise and premium capabilities into the default HSgram feature surface instead of maintaining separate iOS product tiers.

## Current State

The first scaffold builds the app shell, old-style email/code auth flow with native MTProto `auth.sendCode`/`auth.signIn`/`auth.signUp`, server-supplied sign-up TOS parsing/confirmation, sign-up avatar selection/upload through `photos.uploadProfilePhoto`, login-password SRP handling, login-password setup/change/remove through `account.updatePasswordSettings`, recovery-email confirmation through `account.confirmPasswordEmail` / `account.resendPasswordEmail` / `account.cancelPasswordEmail`, password recovery through `auth.requestPasswordRecovery` / `auth.recoverPassword`, Keychain current-session and saved-account persistence, local account switching/add-account flow, HSgram_ios-style three-tab root navigation (`Today`, `Chats`, `Settings`), foreground MTProto `updates.getState` / `updates.getDifference` sync polling, chat list filters with mark-read/mark-unread parity plus pinned/Archived filter/archive/reorder actions and server-backed custom folder tabs plus create/edit/delete/reorder/tag-display management backed by native MTProto dialog and folder APIs, chat thread UI with paged history loading, HSgram_ios-style message bubbles/wallpaper/composer, unread separator with first-unread initial scroll, outgoing sending/failed/read receipts backed by local text/media-send pending/failed retry states, existing `read_outbox_max_id` / `messages.getPeerDialogs` state, and outbox-read sync updates, replies, reply previews with jump-to-original, left-swipe reply, URL/mention/hashtag taps, in-chat search, message multi-select copy/forward/delete, Saved Messages self-chat, server-backed drafts, an attachment menu shell, photo/video/file send, composer voice-message recording with packed waveform attributes, and native camera photo/video capture through native MTProto upload with bubble-level progress/cancel/retry UI, received photo/video/GIF/audio/voice/file/sticker metadata bubbles with tap-to-download/cache, voice waveform display, progress/cancel/retry, image/video/audio/voice/share preview, local media cache cleanup plus old-style keep-duration/size-limit eviction and Wi-Fi/cellular low/medium/high/custom auto-download controls with contacts/private/group/channel source filters, old size steps, and video preload state, Stories preference parity, and old-style energy-saving threshold/autoplay/background-download controls in Data & Storage, shared media/files/links browsing through native `messages.search` filters with a media grid phase, private-chat entry from contact profiles, global search, supergroup creation, group chat actions, group management with member search, channel listing/creation/management with subscriber search, contact search/request/accept/decline/delete/block/unblock flows plus Settings privacy blocked-users management through native `contacts.getBlocked`, privacy base-rule and per-peer exception editing through native `account.setPrivacy`, trust center, APNS registration/foreground/background refresh hooks, bundled permission/privacy metadata, real settings screens including saved account switcher, server-backed profile load through `users.getFullUser`, profile photo update/removal through `photos.uploadProfilePhoto` / `photos.updateProfilePhoto`, account deletion through `account.deleteAccount`, appearance/language/support/old-style logout options/local passcode app lock with 4/6-digit passcodes, old auto-lock choices, Face ID/Touch ID unlock, biometric domain-state validation, failure throttling, app-switcher privacy cover, and Keychain-backed passcode storage, merged Advanced access, and a typed API client. New groups are always created as supergroups. Circle-specific surfaces are currently paused.

Private-chat notification mute now follows the old HSgram_ios / Android server contract: the chat menu calls native MTProto `account.updateNotifySettings` with `inputNotifyPeer` and `inputPeerNotifySettings.mute_until`, including enable notifications, mute for 1 hour, mute for 2 days, custom-hour mute, and mute forever. The server remains unchanged and persists the setting through the existing `user_notify_settings` state used by Android and PC.

Backend alignment correction: the public `hsgram.cloud` deployment does not expose the native `/v1` REST facade. Caddy only proxies selected existing routes, so `/v1/auth/email/start` hits the static site and returns HTTP 405. The iOS client now disables `/v1` calls by default and only allows them with `HS_NATIVE_REST_BRIDGE=1` for explicit local bridge testing. Production migration must follow the old HSgram-ios server protocol, including `auth.sendCode`, `auth.signIn`, `auth.signUp`, and the existing message/channel/contact services. The remaining 1:1 scope is tracked in `FULL_MIGRATION_MATRIX.md`.

Production MTProto endpoint note: the native client defaults to the currently reachable HSgram server entrypoint `43.134.228.34:11443`, with `124.220.11.177:5222` kept as a verified fallback for compatibility with the existing Android/PC deployment path. Both endpoints have been verified to answer MTProto `req_pq_multi` with `resPQ`. For explicit test builds, override with `HS_NATIVE_MTPROTO_HOST`, `HS_NATIVE_MTPROTO_PORT`, and optional comma-separated `HS_NATIVE_MTPROTO_FALLBACKS` values such as `host:port,host2:port2`.

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
