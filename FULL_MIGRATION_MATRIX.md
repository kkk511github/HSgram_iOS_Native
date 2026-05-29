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
| Account and auth | Email-only sign-in/register, saved accounts, account switching, logout, sessions/devices, account deletion, profile, username | Use existing `auth.sendCode`, `auth.signIn`, `auth.signUp`, `auth.requestPasswordRecovery`, `auth.recoverPassword`, `account.updatePasswordSettings`, `account.confirmPasswordEmail`, `account.resendPasswordEmail`, `account.cancelPasswordEmail`, `account.deleteAccount`, authsession, and user state; do not use undeployed `/v1` by default | Bridge UI exists for old-style email/code flow, HSgram-style code-card UI, first-name/last-name/invite-code sign-up fields, server-supplied sign-up TOS parsing/confirmation, sign-up avatar selection plus existing MTProto `photos.uploadProfilePhoto`, native MTProto production auth transport, `account.getPassword`/SRP login password handling, login-password setup/change/remove through existing password-settings APIs, recovery-email confirm/resend/cancel, password recovery code request/submit through existing MTProto recovery APIs, Keychain current-session and saved-account persistence, local account switching/add-account flow, old-style logout options, account deletion through existing `account.deleteAccount`, profile, username, and non-current device reset; remaining work is review-account login-password/recovery E2E |
| Today workspace | Action Inbox, counts, review items, quick actions | Use existing dialogs, contacts, authorizations/trust, and group/channel state; do not depend on undeployed `/v1` summary | Bridge with native MTProto aggregation for unread dialogs, contact requests, and device/trust review actions; join-request/rules counters remain tied to later group parity work |
| Dialogs | Private chats, groups, saved messages, unread state, pinned/archived state, custom folders | Use existing dialog BFF/service state | Bridge with UI for dialog list, saved messages self-chat, contact-to-private-chat, old-style 75pt chat-list rows with 60pt avatars, right-aligned time, top-line outgoing sending/failed/sent/read status icons based on local send state plus existing top-message/read-outbox state, bottom-right unread/marked-unread/pinned accessories, title mute icons, pinned row background, old-style All/Unread/Contacts/Groups/Archived filters, mark-read with old iOS peer splitting through `messages.readHistory` for private/basic groups and `channels.readHistory` for channels/supergroups, manual mark-unread via existing `messages.markDialogUnread`, unread-mark parsing from dialog flags, muted-state parsing, pin flag parsing, pinned-first ordering, pin/unpin through existing `messages.toggleDialogPin`, pinned dialog drag reorder through existing `messages.reorderPinnedDialogs`, archive/unarchive through existing MTProto `folders.editPeerFolders` plus `messages.getDialogs` `folder_id`, clear history/delete chat/delete for both with old iOS peer splitting through `messages.deleteHistory` for private/basic groups and `channels.deleteHistory` for channels/supergroups, server-backed custom folder tabs plus native create/edit/delete/reorder/tag-display management through `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags`, and shared folder invite/update/leave protocol facades through existing `chatlists.*` MTProto; planned for tag-color polish and final visual parity |
| Message history | Text history, service messages, read state, pagination | Use existing messages BFF and message store | Bridge with UI/API for history, read refresh, load-older pagination, old-style unread separator/first-unread initial scroll based on existing dialog unread counts, per-day chat date separators, adjacent same-author bubble grouping with merged tails/corners, incoming group avatar column with reserved alignment placeholders and tail-only avatar display, outgoing read receipts backed by existing `read_outbox_max_id` / `messages.getPeerDialogs` state plus `updates.getDifference` outbox-read updates, message-content consume state through existing `messages.readMessageContents` and `channels.readMessageContents`, refreshed channel post view/forward/reply counters through old-iOS `messages.getMessagesViews`, group/channel read participant snapshots through old-iOS `messages.getMessageReadParticipants#31c1c44f`, message reaction detail pages through old-iOS/server `messages.getMessageReactionsList#461b3f48`, edited-message status labels, channel author signatures, and channel post view/reply counters parsed from existing MTProto message fields; current mock UI branch is intentionally not wired to these new service calls yet |
| Sending | Text, media, documents, voice, replies, forwards, edits, deletes, pins, drafts | Send through existing `messages.*` / `channels.*` / `msg` / sync path | Bridge with UI for text/replies/left-swipe reply/reply preview and jump/forward/edit/delete/reactions/pins/message links/URL taps/mention and hashtag taps/server drafts, multi-select copy/forward/delete, plus attachment menu shell; poll/todo protocol facades now route to existing server MTProto `messages.sendMedia(inputMediaPoll)`, `messages.sendMedia(inputMediaTodo)`, `messages.sendVote`, `messages.getPollResults`, `messages.getPollVotes`, `messages.toggleTodoCompleted`, and `messages.appendTodoList`, with UI still mock-driven; text and media sends now surface old-style local `.Sending` / `.Failed` bubble states with retry/delete before server confirmation; message delete now follows old iOS peer splitting with private/basic group messages using `messages.deleteMessages` and channel/supergroup messages using `channels.deleteMessages`; message bubbles parse and render existing MTProto `MessageReactions` / `ReactionCount` state with optimistic reaction feedback; photo/video/file/voice-message send is mapped to existing MTProto `upload.*` + `inputMediaUploaded*` + `messages.sendMedia` path with bubble-level upload progress, cancel, and retry-after-failure UI; received photo/video/GIF/audio/voice/file metadata now parses from `messageMedia*`; received-media downloads now use existing MTProto `upload.getFile` |
| Media | Photo/video picker, camera, documents, downloads, shared media browser, storage controls | Use existing media/dfs services and shared media indexes | Bridge for gallery/file picker, native camera photo/video capture, voice recording, and file send using existing DFS upload and `messages.sendMedia`, including video, voice, voice waveform, and GIF document attributes; message bubbles now distinguish received photo/video/GIF/audio/voice/file/sticker metadata from MTProto photo/document attributes, parse historical `messageMediaWebPage`/`WebPage` link previews including cached-page and webpage-attribute skip paths, fetch composer-side live link previews through existing `messages.getWebPagePreview`, preserve dismissed previews through `no_webpage` on send/draft, and can download received media into a reusable local cache with progress, cancel, failed-download retry, image/video/audio preview, voice waveform display, file share handoff, Settings cleanup, old-style automatic cache eviction by keep duration and size limit, and local low/medium/high/custom auto-download controls with contacts/private/group/channel source filters, old size steps, video preload state, Stories preference parity, energy-saving/background gating, and chat pre-cache; shared media browsing now uses native MTProto `messages.search` filters for media/files/links/GIF/voice/music with paging, jump-to-message, link-preview titles/descriptions, grid phases for media/GIF, server-backed tab counters through old-iOS `messages.getSearchCounters`, and protocol/facade-ready old calendar/position services through `messages.getSearchResultsCalendar` and `messages.getSearchResultsPositions`; planned for thumbnail-backed grid cells, actual Stories message/server surfaces, and CDN redirect edge cases |
| Stickers and emoji | Sticker packs, custom emoji, reactions, recent/favorites | Use existing sticker/emoji/reaction BFF paths | Bridge at protocol/facade level for asset catalog, available reactions, old-iOS sticker pack identity with access hashes, sticker pack install/uninstall through `messages.installStickerSet` / `messages.uninstallStickerSet`, sticker pack detail by id/access hash or short name through `messages.getStickerSet`, regular emoji sticker suggestions through `messages.getStickers`, custom emoji document resolution through `messages.getCustomEmojiDocuments`, custom emoji set listing through `messages.getEmojiStickers`, custom emoji search through `messages.searchCustomEmoji`, emoji keyword full/difference/language sync through `messages.getEmojiKeywords`, `messages.getEmojiKeywordsDifference`, and `messages.getEmojiKeywordsLanguages`, saved GIF read/save/remove through `messages.getSavedGifs` and `messages.saveGif`, archived pack listing for stickers/masks/emoji through `messages.getArchivedStickers`, featured sticker read state through `messages.readFeaturedStickers`, recent sticker read/save/remove/clear through `messages.getRecentStickers`, `messages.saveRecentSticker`, and `messages.clearRecentStickers`, faved sticker empty-state read through current server `messages.getFavedStickers`, reaction picker cloud state through `messages.getRecentReactions`, `messages.getTopReactions`, `messages.setDefaultReaction`, `messages.clearRecentReactions`, and default reaction read from existing `help.getConfig` `Config.reactionsDefault`; the current UI branch stays mock-driven |
| Contacts | Contacts list, requests, import/invite, block/unblock, user profile | Use existing contacts/user/privacy services | Bridge with UI/API for list, user search, profile view, message entry, request, accept, decline, delete, block, unblock, blocked users list through existing `contacts.getBlocked`, device address-book import through existing `contacts.importContacts`, imported-phone cleanup through existing `contacts.deleteByPhones`, contact notes through `contacts.addContact` / `contacts.updateContactNote`, add-phone privacy exceptions through existing `contacts.addContact` flags, contact share links through existing `contacts.exportContactToken` / `contacts.importContactToken`, profile/report actions through existing report BFF methods, and shared contact invite picker; planned for avatar update/viewing |
| Groups | Create/manage supergroups, member list, admins, permissions, invite links, join requests, rules | Use existing channel/supergroup chat state; new groups use `channels.createChannel` with `megagroup=true` | Bridge with split Groups module for create/detail edit/members plus server-backed recent/admins/contacts/bots/restricted/banned member filters/contact invites/remove/delete member history/configurable admin rights/configurable member restrictions/settings editor including slow mode/join gates/pre-history/member-list visibility/anti-spam protection, public username check/update through existing `channels.checkUsername` / `channels.updateUsername`, configurable invite link create/list/edit/delete plus invite importer/join-request listing and approve/decline service actions through existing `messages.*ChatInvite*` methods, anti-spam false-positive reporting through existing `channels.reportAntiSpamFalsePositive`, message-content consume state through existing `channels.readMessageContents`, mark-read through existing `channels.readHistory`, clear-history through existing `channels.deleteHistory`, message deletion through existing `channels.deleteMessages`, admin logs, and message pins; planned for rules UI and transliterated member search |
| Circles | Circle-specific tools and surfaces | Existing circle endpoints remain untouched | Deferred by current product scope; no main tab entry |
| Trust center | Reports, safety review, device/session review, support, privacy checks | Use existing report/authsession/privacy state | Bridge with native MTProto report adapters for `account.reportPeer`, `account.reportProfilePhoto`, and `messages.report` including old-style report option/comment/result parsing; UI wiring can wait for the mock UI branch |
| Settings | Appearance, language, saved account switcher, privacy/security, notifications, data/storage, help/support | Use existing account/configuration/notification services | Bridge with UI/API for the old `PeerInfoSettingsItems` root grouping, profile backed by `users.getFullUser(inputUserSelf)`, profile photo update/removal through `photos.uploadProfilePhoto` / `photos.updateProfilePhoto`, saved account switcher/add-account, Favorites self-chat entry, Devices, Chat Folders through existing `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags`, privacy summary plus base privacy-rule editing and per-peer exceptions through existing `account.setPrivacy`, blocked users management, notification scopes plus notification exceptions/sounds/reset and saved/uploaded ringtones through existing `account.getNotifyExceptions`, `account.resetNotifySettings`, `account.getSavedRingtones`, `account.saveRingtone`, and `account.uploadRingtone`, language pack list/preview/full-pack/string/difference sync through existing `langpack.getLanguages`, `langpack.getLanguage`, `langpack.getLangPack`, `langpack.getStrings`, and `langpack.getDifference`, data/storage summary, old-style logout options, account deletion, local passcode/app lock with 4/6-digit passcodes, old auto-lock choices, Face ID/Touch ID unlock, biometric domain-state validation, failure throttling, app-switcher privacy cover, Keychain-backed passcode storage with legacy UserDefaults migration, local media cache keep-duration/size-limit controls, local Wi-Fi/cellular auto-download controls with low/medium/high/custom presets, source filters, Stories preference parity, old-style energy-saving threshold/autoplay/background-download toggles, appearance color scheme/text size, language preference, support links, and wallpaper catalog/detail/save/install/reset protocol facade through `account.getWallPapers`, `account.getWallPaper`, `account.saveWallPaper`, `account.installWallPaper`, and `account.resetWallPapers`; planned for dedicated Tips content, separate Power Saving surface, full theme UI assets/app icons/wallpaper UI wiring |
| Notifications | APNS token registration, badges, mute settings, foreground/background updates | Use existing notification service and sync updates | Bridge for mute/settings scopes, notification exceptions/sounds/reset, saved/uploaded ringtones, APNS token registration via `account.registerDevice`, push permission UI, foreground presentation, badge clearing, `remote-notification` background mode, push-triggered refresh of Today/dialog/thread views, and foreground MTProto `updates.getState` / `updates.getDifference` polling that refreshes dialogs and open threads when Android/PC/server-side message, reaction, profile, member, notify/privacy, read/delete/draft/pin/folder/filter/channel/chat updates arrive; planned for notification service/content extensions, rich push rendering, socket-level update streaming, and durable local update application |
| Search | Chats, messages, contacts, media | Use existing search/global search services | Bridge with UI/API for dialogs, contacts, global messages, in-chat message search now routed to current-peer `messages.search` with `inputMessagesFilterEmpty` instead of global-search filtering, keeping the old remote result list, jump-to-message, count, and previous/next navigation pattern, and shared media/file/link/GIF/voice/music filters plus tab counters and old calendar/position service facades through `messages.search`, `messages.getSearchCounters`, `messages.getSearchResultsCalendar`, and `messages.getSearchResultsPositions`; planned for final visual parity |
| Channels | Broadcast channel list, creation, posting, subscribers, invite links, admin log | Use existing channel state with `channels.createChannel` using `broadcast=true` | Bridge with UI/API for list/create/open channel chat, create-time subscriber selection, channel info editing including current linked discussion group from `channels.getFullChannel`, public username check-update service actions through existing `channels.checkUsername` / `channels.updateUsername`, discussion-group candidate listing plus set/unlink service actions through existing `channels.getGroupsForDiscussion` / `channels.setDiscussionGroup`, channel post discussion snapshot/read service actions through existing `messages.getDiscussionMessage` / `messages.readDiscussion`, channel message content-read service actions through existing `channels.readMessageContents`, channel mark-read through existing `channels.readHistory`, channel clear-history through existing `channels.deleteHistory`, channel message deletion through existing `channels.deleteMessages`, channel message signature read/write through current server-compatible `channels.toggleSignatures`, signature profile state parsing from channel flags, anti-spam protection read/write plus false-positive reporting through existing `channels.toggleAntiSpam` / `channels.reportAntiSpamFalsePositive`, subscribers plus server-backed subscriber/admin/bot/restricted/banned filters, contact invites, subscriber removal, configurable admin rights, configurable invite links, and admin log |
| Premium + enterprise merge | Premium assets, admin/business/automation tools, advanced moderation, merged entitlements | Expose one HSgram entitlement surface; no split builds | Bridge |
| App Store hardening | Native bundle, privacy manifest, app icons/screenshots, review account, no Telegram-derived target code/assets | Keep rejected source tree out of app target | In progress; UI root now matches the old HSgram_ios three-tab shape, the default target no longer includes legacy bridge files or optional Telegram/MtProtoKit bridge branches, current App source/project and simulator binary scans are clean for `Telegram`/`MtProtoKit`/`HSMessagingApi`/`OpenSSL`, `Info.plist`/`PrivacyInfo.xcprivacy` are bundled, HSgram-owned AppIcon/AccentColor assets compile, the provided blue HSgram H chat-bubble icon is the product icon reference for final app-icon/metadata/screenshots, and App Store metadata plus screenshot-planning scaffolds exist; planned for final product screenshots, review account notes, and archive-time scans |
| Voice calls | 1:1 voice calls | Keep future compatibility with call services | Deferred |
| Live/group calls | Group voice/video chat and live streaming | Keep future compatibility with call/live services | Deferred |

## Critical Remaining Gaps

- Realtime sync: foreground native MTProto `updates.getState` / `updates.getDifference` polling is wired and refreshes dialog list/open chat threads on detected differences. Common non-message updates now map to affected dialog IDs for reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat changes, including nested collectible emoji status and channel participant rank parsing, while typing/recording/uploading/choosing-sticker updates are parsed into transient chat-header input activity without forcing list refreshes. A persistent socket/push-stream update engine and durable local update database are still pending.
- Binary independence: the default native target builds without legacy bridge sources or Telegram-derived linker/search settings; the optional legacy bridge source files, module map, and compile branch have been removed from the Native project, HSgram-owned AppIcon/AccentColor assets now compile in the native bundle, and App source/project plus simulator `strings`/`otool` scans are clean. Continue archive-time scans before resubmission.
- Dialog organization: archived chats now use the existing MTProto folder path and native Archived filter, pinned chats now parse dialog flags, show pin indicators, sort above unpinned rows, toggle through `messages.toggleDialogPin`, and reorder through `messages.reorderPinnedDialogs`; server-backed custom chat folders now load from `messages.getDialogFilters`, append to the Chats tab, apply include/exclude/pinned/category matching, and can be created, edited, deleted, reordered, and tag-display toggled from native UI. Shared folder links, tag-color polish, and final visual parity remain.
- Media message loop: photo/video/file/voice-message upload/send now use the existing MTProto/DFS path with bubble-level local sending/failed states, progress/cancel/retry UI, camera photo/video capture and composer voice recording feeding the same upload path, received photo/document/webpage metadata parsed into native message bubbles, link previews rendered for historical `messageMediaWebPage`, composer live previews fetched through `messages.getWebPagePreview` and honored dismissed previews with `no_webpage`, download/preview/cache reuse/Settings cleanup, old-style automatic local cache eviction, and Wi-Fi/cellular low/medium/high/custom auto-download pre-cache now use the native cache store with old source filters, size steps, Stories preference parity, and energy-saving/background gating, and shared media/files/links/GIF/voice/music browse through `messages.search` with `messages.getSearchCounters` tab counts, link-preview titles/descriptions, grid phases for media/GIF, and protocol/facade-ready old calendar/position services through `messages.getSearchResultsCalendar` and `messages.getSearchResultsPositions`; thumbnail-backed grid cells, actual Stories message/server surfaces, and CDN redirect support remain.
- Offline storage: there is no local message database, searchable local index, or durable media/message cache layer yet.
- APNS: device-token registration, badge clearing, foreground presentation, `remote-notification` background mode, push-triggered Today/dialog/thread refresh, and foreground MTProto difference polling are wired; notification exceptions/sounds/reset and saved/uploaded ringtones are protocol/facade-ready against existing server MTProto, while notification service/content extensions, rich push rendering, and background socket/long-poll continuity are still pending.
- Rich media: received GIF/video/audio/voice/file/sticker/webpage metadata is identified, voice waveform bytes are sent/parsed/rendered, downloaded videos and audio/voice messages can preview with AVKit/AVPlayer, historical link previews render from server-returned `WebPage` objects, composer live link previews use existing MTProto preview fetching, and message reaction updates now trigger affected chat refresh; sticker pack detail, regular emoji sticker suggestions, custom emoji document resolution, custom emoji set listing/search, emoji keyword full/difference/language sync, and saved GIF read/save/remove are protocol-ready for later UI wiring, reaction picker recent/top/default read/default set/clear are protocol-ready but UI browsing remains mock-unwired, and rendered stickers/custom emoji packs remain incomplete.
- Localization: language preference exists and server langpack list/preview/full-pack/string/difference sync is protocol/facade-ready through existing `langpack.*` MTProto; UI copy is still mostly hard-coded and `Localizable.strings` coverage is not complete.
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

- Auth: email/code UI, HSgram-style code card, first-name/last-name/invite-code sign-up, server-supplied TOS parsing/confirmation, sign-up avatar selection/upload through `photos.uploadProfilePhoto`, native MTProto `auth.sendCode`/`auth.signIn`/`auth.signUp`, `account.getPassword`/SRP login password handling, login-password setup/change/remove through `account.updatePasswordSettings`, recovery-email confirm/resend/cancel, old-style `auth.requestPasswordRecovery` / `auth.recoverPassword` recovery-code flow, Keychain current-session persistence, saved account list, add-account flow, and local account switching are native; real review-account login-password/recovery E2E remains.
- Settings: split into dedicated native files for profile, saved account switcher, appearance, language, privacy, blocked users, notifications, storage, support, devices, advanced tools, old-style logout options, account deletion, local passcode/app lock with Keychain-backed storage and Face ID/Touch ID, and the settings shell; profile now reads server `users.getFullUser(inputUserSelf)`, and the visible settings root follows old account/chat-workflow/experience/support grouping and exposes Favorites, Devices, and Chat Folders from the settings list.
- Private chats: split into dedicated native files for chat list filters, chat thread container, composer/reply accessory panel, attachment menu shell, message bubble/reply reference, in-chat search views, shared media browser, forward target sheet, and message selection toolbar; outgoing bubble and chat-list status now follow the old sending/failed/sent/read shape with local text/media pending/failed retry states, `read_outbox_max_id` from existing MTProto dialog state, and `updateReadHistoryOutbox` / `updateReadChannelOutbox` sync updates; per-day chat date separators, adjacent same-author bubble grouping with merged tails/corners, edited-message labels, and channel author signatures are preserved from existing MTProto `message` fields; message reaction counts now parse from existing MTProto history/update payloads and render as bubble-level reaction capsules; channel post view/reply counters parse from existing MTProto `message` fields and can be refreshed through `messages.getMessagesViews`; read participant snapshots for group/channel messages are protocol/facade-ready through `messages.getMessageReadParticipants#31c1c44f`; reaction detail lists are protocol/facade-ready through existing server `messages.getMessageReactionsList#461b3f48`; media upload/send adapters remain split targets.
- Poll/todo: protocol and facade layers parse `messageMediaPoll` / `messageMediaToDo`, send poll/todo media, submit/refresh/list poll votes, and toggle/append todo items through the existing server MTProto contracts; UI wiring remains intentionally deferred while the current UI branch uses mock data.
- Groups: split into dedicated native files for new supergroup creation, member search support, server-backed recent/admins/contacts/bots/restricted/banned member filters, admin rights editing, member restriction editing, group settings editing including anti-spam protection, anti-spam false-positive reporting, message-content read, read participant snapshots, mark-read, clear-history, and delete service actions, public username check/update service actions, invite link create/list/edit/delete plus invite importer/join-request listing and approve/decline service actions, and supergroup detail edit/members/admins/permissions/invite links/admin log.
- Circles: paused by current product scope.
- Channels: split into dedicated native files for channel list/create/open chat, create-time subscriber selection, and channel detail/public username check-update/discussion-group service actions/post discussion snapshot-read service actions/message views/read-participant/reaction detail list/message content-read/mark-read/clear-history/delete service actions/message signature read-write service actions/anti-spam read-write plus false-positive reporting/subscribers plus server-backed subscriber/admin/bot/restricted/banned filters/subscriber search/admin rights/configurable invite link create/list/edit/delete plus invite importer/join-request listing and approve/decline service actions/admin log; UI visibility/discussion/comment UI polish/signature profile write support/stats remain parity targets.
- Contacts: split into dedicated native files for contacts list, add/search/request sheet, profile actions, blocked users list, contact row, shared contact invite picker, address-book import through existing `contacts.importContacts`, imported-phone cleanup through existing `contacts.deleteByPhones`, contact notes through existing `contacts.addContact` / `contacts.updateContactNote`, add-phone privacy exceptions through existing `contacts.addContact` flags, contact share links through existing `contacts.exportContactToken` / `contacts.importContactToken`, and native report adapters through existing `account.reportPeer`, `account.reportProfilePhoto`, and `messages.report`; avatar gallery, report UI wiring, and richer profile sections remain parity targets.

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
- `GET /v1/settings/notifications/exceptions?scope=&compare_sound=`
- `POST /v1/settings/notifications/reset`
- `GET /v1/settings/storage`
- `GET /v1/localization/languages?lang_pack=`
- `GET /v1/localization/languages/{lang_code}?lang_pack=`
- `GET /v1/localization/packs/{lang_code}?lang_pack=`
- `GET /v1/localization/packs/{lang_code}/difference?lang_pack=&from_version=`
- `GET /v1/localization/strings?lang_pack=&lang_code=&keys=`
- `GET /v1/assets`
- `GET /v1/reactions/recent?limit=&hash=`
- `GET /v1/reactions/top?limit=&hash=`
- `GET /v1/reactions/default`
- `PUT /v1/reactions/default`
- `DELETE /v1/reactions/recent`
- `DELETE /v1/devices/{authorization_id}`
- `PATCH /v1/dialogs/{dialog_id}/notifications`
- `GET /v1/notifications/ringtones?hash=`
- `POST /v1/notifications/ringtones/upload`
- `POST /v1/notifications/ringtones/{document_id}`
- `DELETE /v1/notifications/ringtones/{document_id}`
- `POST /v1/dialogs/{dialog_id}/read`
- `POST /v1/dialogs/{dialog_id}/unread`
- `POST /v1/dialogs/{dialog_id}/pin`
- `PUT /v1/dialogs/pins/order`
- `PUT /v1/dialogs/{dialog_id}/folder`
- `PATCH /v1/dialogs/{dialog_id}/messages/{message_id}`
- `DELETE /v1/dialogs/{dialog_id}/messages/{message_id}`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/forward`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/reactions`
- `GET /v1/dialogs/{dialog_id}/messages/{message_id}/reactions/list?reaction=&offset=&limit=`
- `POST /v1/dialogs/{dialog_id}/messages/read-contents`
- `GET /v1/dialogs/{dialog_id}/messages/{message_id}/discussion`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/discussion/read?read_max_id=`
- `POST /v1/dialogs/{dialog_id}/messages` with `replyToMessageID`
- `GET /v1/dialogs/{dialog_id}/shared-media?filter=&limit=&offset_id=`
- `GET /v1/dialogs/{dialog_id}/shared-media/counters?filters=`
- `GET /v1/dialogs/{dialog_id}/shared-media/calendar?filter=&offset_id=&offset_date=`
- `GET /v1/dialogs/{dialog_id}/shared-media/positions?filter=&limit=&offset_id=`
- `GET /v1/dialogs?folder_id=`
- `GET /v1/dialog-filters/{filter_id}/shared-links`
- `POST /v1/dialog-filters/{filter_id}/shared-links`
- `PATCH /v1/dialog-filters/{filter_id}/shared-links/{slug}`
- `DELETE /v1/dialog-filters/{filter_id}/shared-links/{slug}`
- `GET /v1/chatlist-invites/{slug}`
- `POST /v1/chatlist-invites/{slug}/join`
- `GET /v1/dialog-filters/{filter_id}/chatlist-updates`
- `POST /v1/dialog-filters/{filter_id}/chatlist-updates`
- `DELETE /v1/dialog-filters/{filter_id}/chatlist-updates`
- `GET /v1/dialog-filters/{filter_id}/leave-suggestions`
- `POST /v1/dialog-filters/{filter_id}/leave`
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
- `GET /v1/supergroups/{dialog_id}/username/check`
- `PATCH /v1/supergroups/{dialog_id}/username`
- `POST /v1/supergroups/{dialog_id}/messages/{message_id}/pin`
- `GET /v1/supergroups/{dialog_id}/messages/{message_id}/link`
- `GET /v1/supergroups/{dialog_id}/messages/{message_id}/reactions/list?reaction=&offset=&limit=`
- `POST /v1/supergroups/{dialog_id}/messages/read-contents`
- `POST /v1/supergroups/{dialog_id}/messages/{message_id}/anti-spam/false-positive`
- `GET /v1/supergroups/{dialog_id}/admin-log`
- `POST /v1/supergroups/{dialog_id}/invites`
- `GET /v1/supergroups/{dialog_id}/invites`
- `PATCH /v1/supergroups/{dialog_id}/invites`
- `DELETE /v1/supergroups/{dialog_id}/invites`
- `GET /v1/supergroups/{dialog_id}/invite-importers`
- `POST /v1/supergroups/{dialog_id}/join-requests/{user_id}/approve`
- `POST /v1/supergroups/{dialog_id}/join-requests/{user_id}/decline`
- `POST /v1/supergroups/{dialog_id}/join-requests/approve-all`
- `POST /v1/supergroups/{dialog_id}/join-requests/decline-all`

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
- `GET /v1/channels/{dialog_id}/username/check`
- `PATCH /v1/channels/{dialog_id}/username`
- `GET /v1/channels/discussion-groups`
- `PATCH /v1/channels/{dialog_id}/discussion-group`
- `GET /v1/channels/{dialog_id}/messages/{message_id}/reactions/list?reaction=&offset=&limit=`
- `POST /v1/channels/{dialog_id}/messages/read-contents`
- `POST /v1/channels/{dialog_id}/messages/{message_id}/anti-spam/false-positive`
- `GET /v1/channels/{dialog_id}/admin-log`
- `POST /v1/channels/{dialog_id}/invites`
- `GET /v1/channels/{dialog_id}/invites`
- `PATCH /v1/channels/{dialog_id}/invites`
- `DELETE /v1/channels/{dialog_id}/invites`
- `GET /v1/channels/{dialog_id}/invite-importers`
- `POST /v1/channels/{dialog_id}/join-requests/{user_id}/approve`
- `POST /v1/channels/{dialog_id}/join-requests/{user_id}/decline`
- `POST /v1/channels/{dialog_id}/join-requests/approve-all`
- `POST /v1/channels/{dialog_id}/join-requests/decline-all`

## Local Contacts Facade Draft

- `GET /v1/contacts`
- `POST /v1/contacts/import`
- `DELETE /v1/contacts/import`
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
- `GET /v1/dialogs/{dialog_id}/messages/{message_id}/discussion`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/discussion/read?read_max_id=`
