# HSgram Native iOS Full Migration Matrix

This file is the checklist for replacing the rejected iOS codebase with a native HSgram app. A feature is not considered migrated until the iOS UI, native API contract, backend mapping, and Android/PC interoperability path are all covered.

## Status Legend

- Done: implemented and build-verified in the native project.
- Bridge: native UI exists and server facade is being mapped to existing backend services.
- Planned: required for 1:1 parity, not yet implemented.
- Deferred: intentionally out of first rebuilt submission.

## Backend Alignment Rule

Do not treat `/v1/*` as a production HSgram server contract. The live `hsgram.cloud` Caddy config does not proxy `/v1`, and `POST /v1/auth/email/start` returns HTTP 405 from the static site. The native client now blocks `/v1` by default unless `HS_NATIVE_REST_BRIDGE=1` is set for an explicit local bridge test. Production parity must follow the old `HSgram_ios` protocol and the existing Android/PC interoperable server state; server source and Caddy config stay read-only unless a backend change is explicitly approved.

## Matrix

| Area | Required Scope | Backend Rule | Status |
| --- | --- | --- | --- |
| Account and auth | Email-only sign-in/register, saved accounts, account switching, logout, sessions/devices, account deletion, profile, username | Use existing `auth.sendCode`, `auth.signIn`, `auth.signUp`, `auth.requestPasswordRecovery`, `auth.recoverPassword`, `account.updatePasswordSettings`, `account.confirmPasswordEmail`, `account.resendPasswordEmail`, `account.cancelPasswordEmail`, `account.deleteAccount`, authsession, and user state; do not use undeployed `/v1` by default | Bridge UI exists for old-style email/code flow, HSgram-style code-card UI, first-name/last-name/invite-code sign-up fields, native MTProto production auth transport, `account.getPassword`/SRP login password handling, login-password setup/change/remove through existing password-settings APIs, recovery-email confirm/resend/cancel, password recovery code request/submit through existing MTProto recovery APIs, Keychain current-session and saved-account persistence, local account switching/add-account flow, old-style logout options, account deletion through existing `account.deleteAccount`, profile, username, and non-current device reset; remaining work is server-supplied TOS, sign-up avatar upload, and review-account login-password/recovery E2E |
| Today workspace | Action Inbox, counts, review items, quick actions | Use existing workspace summary and trust/contact/circle tables | Bridge |
| Dialogs | Private chats, groups, saved messages, unread state, pinned/archived state, custom folders | Use existing dialog BFF/service state | Bridge with UI for dialog list, saved messages self-chat, contact-to-private-chat, old-style All/Unread/Contacts/Groups/Archived filters, mark-read, manual mark-unread via existing `messages.markDialogUnread`, unread-mark parsing from dialog flags, muted-state parsing, pin flag parsing, pinned-first ordering, pin/unpin through existing `messages.toggleDialogPin`, pinned dialog drag reorder through existing `messages.reorderPinnedDialogs`, archive/unarchive through existing MTProto `folders.editPeerFolders` plus `messages.getDialogs` `folder_id`, and server-backed custom folder tabs plus native create/edit/delete/reorder/tag-display management through `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags`; planned for shared folder links, tag-color polish, and final visual parity |
| Message history | Text history, service messages, read state, pagination | Use existing messages BFF and message store | Bridge with UI/API for history, read refresh, load-older pagination, and old-style unread separator/first-unread initial scroll based on existing dialog unread counts |
| Sending | Text, media, documents, voice, replies, forwards, edits, deletes, pins, drafts | Send through existing `messages.*` / `msg` / sync path | Bridge with UI for text/replies/left-swipe reply/reply preview and jump/forward/edit/delete/reactions/pins/message links/URL taps/mention and hashtag taps/server drafts, multi-select copy/forward/delete, plus attachment menu shell; photo/video/file/voice-message send is mapped to existing MTProto `upload.*` + `inputMediaUploaded*` + `messages.sendMedia` path with upload progress, cancel, and retry-after-failure UI; received photo/video/GIF/audio/voice/file metadata now parses from `messageMedia*`; received-media downloads now use existing MTProto `upload.getFile` |
| Media | Photo/video picker, camera, documents, downloads, shared media browser, storage controls | Use existing media/dfs services and shared media indexes | Bridge for gallery/file picker, native camera photo/video capture, voice recording, and file send using existing DFS upload and `messages.sendMedia`, including video, voice, voice waveform, and GIF document attributes; message bubbles now distinguish received photo/video/GIF/audio/voice/file/sticker metadata from MTProto photo/document attributes, parse historical `messageMediaWebPage`/`WebPage` link previews including cached-page and webpage-attribute skip paths, fetch composer-side live link previews through existing `messages.getWebPagePreview`, preserve dismissed previews through `no_webpage` on send/draft, and can download received media into a reusable local cache with progress, cancel, failed-download retry, image/video/audio preview, voice waveform display, file share handoff, Settings cleanup, old-style automatic cache eviction by keep duration and size limit, and local low/medium/high/custom auto-download controls with contacts/private/group/channel source filters, old size steps, video preload state, Stories preference parity, energy-saving/background gating, and chat pre-cache; shared media browsing now uses native MTProto `messages.search` filters for media/files/links/GIF/voice/music with paging, jump-to-message, link-preview titles/descriptions, grid phases for media/GIF, and server-backed tab counters through old-iOS `messages.getSearchCounters`; planned for thumbnail-backed grid cells, actual Stories message/server surfaces, and CDN redirect edge cases |
| Stickers and emoji | Sticker packs, custom emoji, reactions, recent/favorites | Use existing sticker/emoji/reaction BFF paths | Last phase; bridge exists for catalog/reactions only |
| Contacts | Contacts list, requests, import/invite, block/unblock, user profile | Use existing contacts/user/privacy services | Bridge with UI/API for list, user search, profile view, message entry, request, accept, decline, delete, block, unblock, blocked users list through existing `contacts.getBlocked`, and shared contact invite picker; planned for address-book import/share invite and avatar update/viewing |
| Groups | Create/manage supergroups, member list, admins, permissions, invite links, join requests, rules | Use existing channel/supergroup chat state; new groups use `channels.createChannel` with `megagroup=true` | Bridge with split Groups module for create/detail edit/members/local member search/contact invites/remove/delete member history/configurable admin rights/configurable member restrictions/settings editor/configurable invite links/admin logs; planned for join-request/rules UIs and remote/transliterated member search |
| Circles | Circle-specific tools and surfaces | Existing circle endpoints remain untouched | Deferred by current product scope; no main tab entry |
| Trust center | Reports, safety review, device/session review, support, privacy checks | Use existing report/authsession/privacy state | Bridge |
| Settings | Appearance, language, saved account switcher, privacy/security, notifications, data/storage, help/support | Use existing account/configuration/notification services | Bridge with UI/API for the old `PeerInfoSettingsItems` root grouping, profile, saved account switcher/add-account, Favorites self-chat entry, Devices, Chat Folders through existing `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags`, privacy summary plus base privacy-rule editing and per-peer exceptions through existing `account.setPrivacy`, blocked users management, notification scopes, data/storage summary, old-style logout options, account deletion, local passcode/app lock with 4/6-digit passcodes, old auto-lock choices, Face ID/Touch ID unlock, biometric domain-state validation, failure throttling, app-switcher privacy cover, Keychain-backed passcode storage with legacy UserDefaults migration, local media cache keep-duration/size-limit controls, local Wi-Fi/cellular auto-download controls with low/medium/high/custom presets, source filters, Stories preference parity, old-style energy-saving threshold/autoplay/background-download toggles, appearance color scheme/text size, language preference, and support links; planned for dedicated Tips content, separate Power Saving surface, full theme assets/app icons/wallpapers/localization packs |
| Notifications | APNS token registration, badges, mute settings, foreground/background updates | Use existing notification service and sync updates | Bridge for mute/settings scopes, APNS token registration via `account.registerDevice`, push permission UI, foreground presentation, badge clearing, `remote-notification` background mode, push-triggered refresh of Today/dialog/thread views, and foreground MTProto `updates.getState` / `updates.getDifference` polling that refreshes dialogs and open threads when Android/PC/server-side message, reaction, profile, member, notify/privacy, read/delete/draft/pin/folder/filter/channel/chat updates arrive; planned for notification service/content extensions, rich push rendering, socket-level update streaming, and durable local update application |
| Search | Chats, messages, contacts, media | Use existing search/global search services | Bridge with UI/API for dialogs, contacts, global messages, in-chat message search using the old remote peer-search/list/jump pattern with count and previous/next navigation, and shared media/file/link/GIF/voice/music filters plus tab counters through `messages.search` and `messages.getSearchCounters`; planned for final visual parity |
| Channels | Broadcast channel list, creation, posting, subscribers, invite links, admin log | Use existing channel state with `channels.createChannel` using `broadcast=true` | Bridge with UI/API for list/create/open channel chat, create-time subscriber selection, channel info editing, subscribers, local subscriber search, contact invites, subscriber removal, configurable admin rights, configurable invite links, and admin log |
| Premium + enterprise merge | Premium assets, admin/business/automation tools, advanced moderation, merged entitlements | Expose one HSgram entitlement surface; no split builds | Bridge |
| App Store hardening | Native bundle, privacy manifest, app icons/screenshots, review account, no Telegram-derived target code/assets | Keep rejected source tree out of app target | In progress; UI root now matches the old HSgram_ios three-tab shape, the default target no longer includes legacy bridge files or optional Telegram/MtProtoKit bridge branches, current App source/project and simulator binary scans are clean for `Telegram`/`MtProtoKit`/`HSMessagingApi`/`OpenSSL`, `Info.plist`/`PrivacyInfo.xcprivacy` are bundled, HSgram-owned AppIcon/AccentColor assets compile, and App Store metadata plus screenshot-planning scaffolds exist; planned for final product screenshots, review account notes, and archive-time scans |
| Voice calls | 1:1 voice calls | Keep future compatibility with call services | Deferred |
| Live/group calls | Group voice/video chat and live streaming | Keep future compatibility with call/live services | Deferred |

## Critical Remaining Gaps

- Realtime sync: foreground native MTProto `updates.getState` / `updates.getDifference` polling is wired and refreshes dialog list/open chat threads on detected differences. Common non-message updates now map to affected dialog IDs for reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat changes, including nested collectible emoji status and channel participant rank parsing, with no-op handling for typing updates and fallback full refresh for unsupported update shapes. A persistent socket/push-stream update engine and durable local update database are still pending.
- Binary independence: the default native target builds without legacy bridge sources or Telegram-derived linker/search settings; the optional legacy bridge source files, module map, and compile branch have been removed from the Native project, HSgram-owned AppIcon/AccentColor assets now compile in the native bundle, and App source/project plus simulator `strings`/`otool` scans are clean. Continue archive-time scans before resubmission.
- Dialog organization: archived chats now use the existing MTProto folder path and native Archived filter, pinned chats now parse dialog flags, show pin indicators, sort above unpinned rows, toggle through `messages.toggleDialogPin`, and reorder through `messages.reorderPinnedDialogs`; server-backed custom chat folders now load from `messages.getDialogFilters`, append to the Chats tab, apply include/exclude/pinned/category matching, and can be created, edited, deleted, reordered, and tag-display toggled from native UI. Shared folder links, tag-color polish, and final visual parity remain.
- Media message loop: photo/video/file/voice-message upload/send now use the existing MTProto/DFS path with progress/cancel/retry UI, camera photo/video capture and composer voice recording feed the same upload path, received photo/document/webpage metadata is parsed into native message bubbles, link previews render for historical `messageMediaWebPage`, composer live previews fetch through `messages.getWebPagePreview` and honor dismissed previews with `no_webpage`, download/preview/cache reuse/Settings cleanup, old-style automatic local cache eviction, and Wi-Fi/cellular low/medium/high/custom auto-download pre-cache now use the native cache store with old source filters, size steps, Stories preference parity, and energy-saving/background gating, and shared media/files/links/GIF/voice/music browse through `messages.search` with `messages.getSearchCounters` tab counts, link-preview titles/descriptions, and grid phases for media/GIF; thumbnail-backed grid cells, actual Stories message/server surfaces, and CDN redirect support remain.
- Offline storage: there is no local message database, searchable local index, or durable media/message cache layer yet.
- APNS: device-token registration, badge clearing, foreground presentation, `remote-notification` background mode, push-triggered Today/dialog/thread refresh, and foreground MTProto difference polling are wired; notification service/content extensions, rich push rendering, and background socket/long-poll continuity are still pending.
- Rich media: received GIF/video/audio/voice/file/sticker/webpage metadata is identified, voice waveform bytes are sent/parsed/rendered, downloaded videos and audio/voice messages can preview with AVKit/AVPlayer, historical link previews render from server-returned `WebPage` objects, composer live link previews use existing MTProto preview fetching, and message reaction updates now trigger affected chat refresh; rendered stickers, custom emoji packs, and full reaction/sticker browsing remain incomplete.
- Localization: language preference exists, but UI copy is still mostly hard-coded; `Localizable.strings` coverage is not complete.
- Tests: unit, integration, and UI coverage are not yet at release gate level.

## First Verification Gate

## Module Migration Gate

The rebuild is now tracked by module in `MODULE_MIGRATION_PLAN.md`. A module is not complete until:

- The old `HSgram_ios` module source paths are reviewed.
- Native files are split along that module boundary.
- Every non-deferred user-facing action in the old module has a native UI path.
- The native path uses the existing HSgram server/API contract without editing server source.
- Any suggested optimization is written down for approval instead of silently changing old behavior.
- The module builds successfully after the changes.

Current module boundary status:

- Auth: email/code UI, HSgram-style code card, first-name/last-name/invite-code sign-up, native MTProto `auth.sendCode`/`auth.signIn`/`auth.signUp`, `account.getPassword`/SRP login password handling, login-password setup/change/remove through `account.updatePasswordSettings`, recovery-email confirm/resend/cancel, old-style `auth.requestPasswordRecovery` / `auth.recoverPassword` recovery-code flow, Keychain current-session persistence, saved account list, add-account flow, and local account switching are native; server-supplied TOS, sign-up avatar upload, and real review-account login-password/recovery E2E remain.
- Settings: split into dedicated native files for profile, saved account switcher, appearance, language, privacy, blocked users, notifications, storage, support, devices, advanced tools, old-style logout options, account deletion, local passcode/app lock with Keychain-backed storage and Face ID/Touch ID, and the settings shell; the visible settings root now follows old account/chat-workflow/experience/support grouping and exposes Favorites, Devices, and Chat Folders from the settings list.
- Private chats: split into dedicated native files for chat list filters, chat thread container, composer/reply accessory panel, attachment menu shell, message bubble/reply reference, in-chat search views, shared media browser, forward target sheet, and message selection toolbar; media upload/send adapters remain split targets.
- Groups: split into dedicated native files for new supergroup creation, member search support, admin rights editing, member restriction editing, group settings editing, invite link options, and supergroup detail edit/members/admins/permissions/invite links/admin log.
- Circles: paused by current product scope.
- Channels: split into dedicated native files for channel list/create/open chat, create-time subscriber selection, and channel detail/subscribers/subscriber search/admin rights/configurable invite links/admin log; visibility/discussion/stats remain parity targets.
- Contacts: split into dedicated native files for contacts list, add/search/request sheet, profile actions, blocked users list, contact row, and shared contact invite picker; address-book import/invite, avatar gallery, report flow, and richer profile sections remain parity targets.

## First Verification Gate

The first useful end-to-end gate is:

1. Register a new account with email on native iOS.
2. See the same account on server auth/user tables.
3. Send iOS -> Android, Android -> iOS, iOS -> PC, PC -> iOS text messages.
4. Verify read/unread state and workspace counts do not diverge.
5. Confirm no mock session or fallback mock chat data is present in the iOS binary path.

Current deployment check: `POST https://hsgram.cloud/v1/auth/email/start` returns HTTP 405 from the public host because `/v1` is not proxied to the HSgram server. The iOS client now stops calling the undeployed facade by default and reports that the old HSgram-ios protocol adapter is required.

## Local Native REST Facade Draft (Not Production)

These routes exist only as a local client/server facade draft. They are not part of the live `hsgram.cloud` contract and must not be used for App Store production until explicitly approved and deployed.

- `GET /v1/account/profile`
- `PATCH /v1/account/profile`
- `DELETE /v1/account`
- `GET /v1/settings/privacy`
- `PATCH /v1/settings/privacy`
- `GET /v1/settings/notifications`
- `PATCH /v1/settings/notifications`
- `GET /v1/settings/storage`
- `DELETE /v1/devices/{authorization_id}`
- `POST /v1/dialogs/{dialog_id}/read`
- `POST /v1/dialogs/{dialog_id}/unread`
- `POST /v1/dialogs/{dialog_id}/pin`
- `PUT /v1/dialogs/pins/order`
- `PUT /v1/dialogs/{dialog_id}/folder`
- `PATCH /v1/dialogs/{dialog_id}/messages/{message_id}`
- `DELETE /v1/dialogs/{dialog_id}/messages/{message_id}`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/forward`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/reactions`
- `POST /v1/dialogs/{dialog_id}/messages` with `replyToMessageID`
- `GET /v1/dialogs/{dialog_id}/shared-media?filter=&limit=&offset_id=`
- `GET /v1/dialogs/{dialog_id}/shared-media/counters?filters=`
- `GET /v1/dialogs?folder_id=`
- `GET /v1/drafts`
- `PUT /v1/dialogs/{dialog_id}/draft`

## Local Supergroup Facade Draft

- `POST /v1/supergroups`
- `GET /v1/supergroups/{dialog_id}`
- `PATCH /v1/supergroups/{dialog_id}`
- `POST /v1/supergroups/{dialog_id}/leave`
- `GET /v1/supergroups/{dialog_id}/members`
- `POST /v1/supergroups/{dialog_id}/members`
- `DELETE /v1/supergroups/{dialog_id}/members/{user_id}`
- `DELETE /v1/supergroups/{dialog_id}/members/{user_id}/history`
- `PATCH /v1/supergroups/{dialog_id}/admins/{user_id}`
- `PATCH /v1/supergroups/{dialog_id}/members/{user_id}/restrictions`
- `PATCH /v1/supergroups/{dialog_id}/settings`
- `POST /v1/supergroups/{dialog_id}/messages/{message_id}/pin`
- `GET /v1/supergroups/{dialog_id}/messages/{message_id}/link`
- `GET /v1/supergroups/{dialog_id}/admin-log`
- `POST /v1/supergroups/{dialog_id}/invites`

## Local Channel Facade Draft

- `GET /v1/channels`
- `POST /v1/channels`
- `GET /v1/channels/{dialog_id}`
- `PATCH /v1/channels/{dialog_id}`
- `POST /v1/channels/{dialog_id}/leave`
- `GET /v1/channels/{dialog_id}/subscribers`
- `POST /v1/channels/{dialog_id}/subscribers`
- `DELETE /v1/channels/{dialog_id}/subscribers/{user_id}`
- `PATCH /v1/channels/{dialog_id}/admins/{user_id}`
- `GET /v1/channels/{dialog_id}/admin-log`
- `POST /v1/channels/{dialog_id}/invites`

## Local Contacts Facade Draft

- `GET /v1/contacts`
- `GET /v1/contacts/blocked`
- `GET /v1/contacts/search`
- `POST /v1/contacts/requests`
- `POST /v1/contacts/{user_id}/accept`
- `POST /v1/contacts/{user_id}/decline`
- `DELETE /v1/contacts/{user_id}`
- `POST /v1/contacts/{user_id}/block`
- `DELETE /v1/contacts/{user_id}/block`

## Local Search Facade Draft

- `GET /v1/search`

## Local Message History Facade Draft

- `GET /v1/dialogs/{dialog_id}/messages?limit=&before_id=`
