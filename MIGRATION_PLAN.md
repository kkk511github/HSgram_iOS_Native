# HSgram iOS Native Migration Plan

## Non-negotiables

- New iOS code must remain independent from the Telegram-iOS source tree.
- Bundle identifier remains `com.hsgram.app` unless App Store Connect strategy changes deliberately.
- Registration and sign-in are email-only in the iOS UI.
- Android and PC must continue to see the same users, dialogs, messages, contacts, group state, moderation events, and trust/report state.
- The iOS client should use a HSgram-native API facade, while the server facade writes to the same backend stores and sync paths used by existing MTProto clients.
- All current iOS capabilities must be migrated into this project before this becomes the App Store submission candidate.
- Enterprise features and premium features are merged into one HSgram feature surface. The native iOS app should not expose separate "enterprise build" or "premium-only build" concepts.
- Voice calls and live streaming are explicitly deferred for the first rebuilt submission, but their navigation placeholders and server compatibility assumptions should not block future implementation.

## Bridge Contract

Initial HTTPS endpoints expected by the native iOS client:

| Area | Method | Path | Purpose |
| --- | --- | --- | --- |
| Auth | POST | `/v1/auth/email/start` | Send email verification code for sign-in or registration. |
| Auth | POST | `/v1/auth/email/verify` | Verify code, create account if needed, and return app session. |

Native auth state should persist the returned session locally in iOS Keychain and clear it on logout. Production auth follows MTProto instead of undeployed native HTTPS routes; sign-up now uses old-iOS first name, last name, and invite-code payload conventions over existing `auth.signUp`, login-password setup/change/remove uses existing `account.updatePasswordSettings`, recovery-email confirmation uses existing `account.confirmPasswordEmail` / `account.resendPasswordEmail` / `account.cancelPasswordEmail`, and login-password recovery uses the existing old-iOS `auth.requestPasswordRecovery` / `auth.recoverPassword` backend path. Old-iOS parity gaps that still need native UI/protocol work, such as server-supplied terms of service, avatar upload during sign-up, Apple token login if retained, and review-account E2E should stay documented client TODOs until the existing backend path is explicitly approved for native use.
| Account | GET/PATCH | `/v1/account/profile` | Read and update display name, username, and bio. |
| Account | DELETE | `/v1/account` | Delete the current account through existing `account.deleteAccount`, with optional SRP password proof when required. |
| Settings | GET/PATCH | `/v1/settings/privacy` | Read privacy rule summaries and write base privacy rules plus Always Allow/Never Allow peer exceptions through existing `account.getPrivacy` / `account.setPrivacy`. |
| Settings | GET/PATCH | `/v1/settings/notifications` | Read and update private chat, group, and channel notification scopes. |
| Settings | GET | `/v1/settings/storage` | Read storage and asset summary for the settings screen. |
| Workspace | GET | `/workspace/summary` | Existing summary for Today metrics/actions. |
| Dialogs | GET | `/v1/dialogs` | List private chats and groups for the active iOS migration scope. |
| Dialogs | POST | `/v1/dialogs/{dialog_id}/pin` | Pin or unpin a dialog through existing `messages.toggleDialogPin`. |
| Dialogs | PUT | `/v1/dialogs/pins/order` | Reorder pinned dialogs through existing `messages.reorderPinnedDialogs`. |
| Dialogs | GET | `/v1/dialogs?folder_id=1` | List archived dialogs through existing `messages.getDialogs` folder loading. |
| Dialogs | PUT | `/v1/dialogs/{dialog_id}/folder` | Archive or unarchive a dialog through existing `folders.editPeerFolders`. |
| Dialogs | GET/PUT/DELETE | `/v1/dialog-filters`, `/v1/dialog-filters/{id}`, and `/v1/dialog-filters/tags` | Read, update/delete, reorder, and toggle tag display for server chat folders through existing `messages.getDialogFilters`, `messages.updateDialogFilter`, `messages.updateDialogFiltersOrder`, and `messages.toggleDialogFilterTags`. |
| Drafts | GET | `/v1/drafts` | Fetch current server-backed text drafts and reply targets for dialogs. |
| Drafts | PUT | `/v1/dialogs/{dialog_id}/draft` | Save or clear a text draft through the shared draft sync path. |
| Search | GET | `/v1/search` | Search dialogs, contacts, and global message history from the shared backend. |
| Messages | GET | `/v1/dialogs/{dialog_id}/messages?limit=&before_id=` | Fetch recent or older paged messages for a dialog. |
| Messages | GET | `/v1/dialogs/{dialog_id}/shared-media?filter=&limit=&offset_id=` | Browse media, files, links, GIFs, voice messages, and music through existing `messages.search` filters. |
| Messages | GET | `/v1/dialogs/{dialog_id}/shared-media/counters?filters=` | Read shared media tab counters through old-iOS `messages.getSearchCounters` using the same media/file/link/GIF/voice/music filters. |
| Messages | POST | `/v1/dialogs/{dialog_id}/messages` | Send a text or reply message into the shared message pipeline. |
| Circles | GET | `/v1/circles` | Existing endpoint remains untouched; circle-specific iOS work is paused by current product scope. |
| Channels | GET/POST | `/v1/channels` | List broadcast channels and create new broadcast channels. |
| Channels | GET/PATCH | `/v1/channels/{dialog_id}` | Read or update channel title/about details. |
| Channels | GET/POST | `/v1/channels/{dialog_id}/subscribers` | List channel subscribers and invite contacts. |
| Channels | DELETE | `/v1/channels/{dialog_id}/subscribers/{user_id}` | Remove a channel subscriber. |
| Channels | PATCH | `/v1/channels/{dialog_id}/admins/{user_id}` | Promote/demote channel admins with channel-compatible rights. |
| Channels | GET | `/v1/channels/{dialog_id}/admin-log` | Read channel administration events. |
| Channels | POST | `/v1/channels/{dialog_id}/invites` | Export a channel invite link. |
| Supergroups | POST | `/v1/supergroups` | Create every new group as a supergroup through `channels.createChannel` with `megagroup=true`. |
| Supergroups | GET/PATCH | `/v1/supergroups/{dialog_id}` | Read or update supergroup title/about details. |
| Supergroups | GET/POST | `/v1/supergroups/{dialog_id}/members` | List members and invite users into the supergroup. |
| Supergroups | DELETE | `/v1/supergroups/{dialog_id}/members/{user_id}` | Remove a supergroup member. |
| Supergroups | DELETE | `/v1/supergroups/{dialog_id}/members/{user_id}/history` | Delete a removed member's message history in the supergroup. |
| Supergroups | PATCH | `/v1/supergroups/{dialog_id}/admins/{user_id}` | Promote/demote admins and set Telegram-compatible admin rights. |
| Supergroups | PATCH | `/v1/supergroups/{dialog_id}/members/{user_id}/restrictions` | Restrict or unrestrict member permissions. |
| Supergroups | PATCH | `/v1/supergroups/{dialog_id}/settings` | Update slow mode, hidden participants, pre-history visibility, and join controls. |
| Supergroups | POST | `/v1/supergroups/{dialog_id}/messages/{message_id}/pin` | Pin or unpin a supergroup message. |
| Supergroups | GET | `/v1/supergroups/{dialog_id}/messages/{message_id}/link` | Export a shareable supergroup message link. |
| Supergroups | GET | `/v1/supergroups/{dialog_id}/admin-log` | Read recent supergroup administration events. |
| Supergroups | POST | `/v1/supergroups/{dialog_id}/invites` | Export a supergroup invite link. |
| Supergroups | POST | `/v1/supergroups/{dialog_id}/leave` | Leave a supergroup. |
| Contacts | GET | `/v1/contacts` | List accepted contacts plus incoming/outgoing pending contact requests. |
| Contacts | GET | `/v1/contacts/blocked` | List blocked users through existing `contacts.getBlocked` for Settings privacy management. |
| Contacts | GET | `/v1/contacts/search` | Search HSgram users before sending a contact request. |
| Contacts | POST | `/v1/contacts/requests` | Send a one-way contact request through the existing HSgram contact state path. |
| Contacts | POST | `/v1/contacts/{user_id}/accept` | Accept a pending contact request and create the mutual contact relation. |
| Contacts | POST | `/v1/contacts/{user_id}/decline` | Decline a pending contact request without creating a contact relation. |
| Contacts | DELETE | `/v1/contacts/{user_id}` | Delete an accepted contact. |
| Contacts | POST/DELETE | `/v1/contacts/{user_id}/block` | Block or unblock a user through the shared contact/privacy backend. |
| Trust | GET | `/v1/trust/items` | List trust events, reports, devices, and safety actions. |
| Devices | GET/DELETE | `/v1/devices`, `/v1/devices/{authorization_id}` | List active sessions and remotely log out non-current devices. |
| Premium + Enterprise | GET | `/v1/entitlements` | Return merged feature entitlement state for formerly premium and enterprise capabilities. |
| Admin Tools | GET | `/v1/admin/tools` | Return group automation, moderation, reports, and operational tools available to the user. |

## Server Rule

The bridge cannot create a parallel chat store. Message sends must end in the same `msg` / sync path used by Android and PC, so cross-platform clients receive normal updates.

Going forward, native iOS feature work should align to existing HSgram server endpoints and shared backend state. If a feature has no existing server path, keep the iOS structure/TODO scoped on the client side until the backend contract is explicitly approved.

## Full Migration Scope

The rebuilt app must cover:

- Account: email sign-in/register, logout, sessions/devices, delete account, username/profile, privacy and security.
- Messaging: dialog list, private chats, groups, message history, text/media messages, replies, forwards, edits, deletes, pins, unread/read state, search, mentions, reactions, drafts, saved messages.
- Media: photo/video picker, camera, documents, voice messages, link previews, downloads, storage settings, shared media browser.
- Contacts: contacts list, contact requests, invite flows, block/unblock, blocked users management, profile view, address-book import, avatar viewing, and report flow.
- Groups: creation, member list, admins, permissions, invite links, join requests, rules, recent actions, auto messages. Every newly created group in the native iOS app is a supergroup.
- Trust and moderation: report flows, spam/safety review, trust events, support, privacy checks.
- Merged premium + enterprise: advanced moderation/automation, premium assets/features currently present in backend, business/admin tools, without splitting product tiers in the iOS UX.
- Notifications: APNS registration through `account.registerDevice`, mute settings, badge/unread behavior, foreground/background update handling.
- Settings: appearance, language, data/storage, privacy, notifications, devices, help/support.
- App Store hardening: no Telegram-derived binary modules/assets/strings in the rebuilt target, complete privacy manifest, HSgram-owned AppIcon/AccentColor assets, App Store metadata/screenshots scaffold, review account path through email only.

Current UI parity pass:

- The native root has been reshaped to match the old HSgram_ios root navigation: Today, Chats, and Settings are the only persistent bottom tabs.
- Email auth now routes to the deployed HSgram MTProto protocol in the default target: `auth.sendCode`, `auth.signIn`, `auth.signUp`, `account.getPassword`/SRP for login-password accounts, `account.updatePasswordSettings` plus password-email confirm/resend/cancel APIs for login-password setup, and old-style `auth.requestPasswordRecovery` / `auth.recoverPassword` for recovery-code login.
- Search, contacts, and channel entry points are now reachable from the Chats surface instead of appearing as separate root tabs.
- Dialog list parity now includes manual mark-unread/mark-read through existing MTProto dialog unread marks, pinned flag parsing and pin/unpin through `messages.toggleDialogPin`, pinned-first ordering, pinned drag reorder through `messages.reorderPinnedDialogs`, an Archived filter backed by `messages.getDialogs(folder_id: 1)`, archive/unarchive actions backed by existing `folders.editPeerFolders`, and server-backed custom chat folder tabs plus native create/edit/delete/reorder/tag-display management from `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags` with include/exclude/pinned/category matching.
- Foreground sync now follows the old MTProto update-state path: native iOS bootstraps `updates.getState`, polls `updates.getDifference`, persists per-account sync state, parses common message/reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat update constructors into affected dialog IDs, ignores transient typing updates without resetting state, and refreshes Chats/open threads when server-side changes are detected so Android/PC changes can surface without relying only on APNS.
- Chat threads now use HSgram_ios-style visual cues in SwiftUI: inline avatar/title header, patterned chat wallpaper, tailed incoming/outgoing bubbles, centered service-message pills, unread separator with first-unread initial scroll, and a rounded input panel.
- Chat media messages now parse native MTProto photo/document/webpage metadata, render distinct photo/video/GIF/audio/voice/file/sticker/link-preview bubbles including voice waveform bytes, support composer-side live link previews through existing `messages.getWebPagePreview` plus `no_webpage` dismissal on send/draft, support tap-to-download through native `upload.getFile` with reusable local cache plus image/video/audio/file preview, expose upload/download progress, cancel, retry, cache stats, cache cleanup UI, old-style keep-duration/size-limit cache eviction, and Wi-Fi/cellular low/medium/high/custom auto-download pre-cache controls with contacts/private/group/channel source filters, old size steps, video preload state, Stories preference parity, and energy-saving/background gating, route native camera photo/video capture and composer voice recording into the same MTProto send path, and browse shared media/files/links/GIF/voice/music through `messages.search` with `messages.getSearchCounters` tab counts, link-preview title/description rows, and grid phases for media/GIF; albums/pasteboard/editor tools, thumbnail-backed shared-media cells, full calendar parity, actual Stories message/server surfaces, and CDN redirects remain.
- Settings/account parity now uses the old `PeerInfoSettingsItems` root grouping instead of native-only server/developer sections, including account/trust/privacy, chat workflows with Favorites, Devices, and Chat Folders, experience preferences, support, logout, and delete-account. Account deletion uses existing `account.deleteAccount`, including optional SRP password proof and local session/auth-key cleanup after server confirmation; privacy base-rule and per-peer exception editing use `account.setPrivacy`; blocked users use existing `contacts.getBlocked` and `contacts.unblock`; local passcode/app lock supports 4/6-digit passcodes, old auto-lock choices, Face ID/Touch ID unlock, biometric domain-state validation, failure throttling, app-switcher privacy cover, and Keychain-backed passcode storage with legacy UserDefaults migration.
- Binary independence pass is underway: the default target now builds without the old Telegram-derived bridge files, optional legacy bridge compile branch, or linker/search settings, App source/project plus simulator binary scans are clean for `Telegram`/`MtProtoKit`/`HSMessagingApi`/`OpenSSL`, and the bundle now has HSgram-owned AppIcon/AccentColor plus App Store metadata and screenshot-planning scaffolds. Continue archive-time scans before submission.

Deferred from the first rebuilt submission:

- 1:1 voice calls.
- Group voice/video chat.
- Live streaming.

## Phases

1. Native app shell: buildable Xcode project, email-only auth UI, HSgram tab structure.
2. Bridge MVP: implement email auth, dialogs, messages, workspace summary using existing BFF/DAO paths.
3. Module migration pass: follow `MODULE_MIGRATION_PLAN.md` and complete Settings, private chats, groups, channels, contacts, media/stickers, notifications/extensions, and App Store hardening as module-sized work instead of scattered feature patches.
4. Full migration matrix: implement every non-deferred screen/action/API from the old iOS client, merging premium and enterprise features into the default HSgram surface.
5. Interop verification: send iOS -> Android, Android -> iOS, iOS -> PC, PC -> iOS; verify read/unread, group/circle membership, contact requests, reporting, admin tools, merged entitlements, and account deletion.
6. App Store hardening: icons/screenshots/metadata, privacy manifest, no Telegram binary strings/assets/modules.
