# Old iOS Source Migration Outline

This is the working outline for rebuilding HSgram iOS independently from the rejected Telegram-derived iOS app while preserving the user-facing HSgram feature set. The old source tree remains the feature reference, but code, binary modules, assets, and Telegram-branded implementation details must not be copied into the native target.

## Source Evidence

- Old iOS source: `/Users/kk/Desktop/HSgram/HSgram_ios`
- Native rebuild source: `/Users/kk/Desktop/HSgram/HSgram_iOS_Native`
- Shared backend source: `/Users/kk/Desktop/HSgram/HSgram_server`
- CodeGraph old-iOS index: 24,818 indexed files, 520,708 symbols, 1,571,977 edges.
- Old-iOS indexed languages: 4,715 Swift files, 10,418 C++ files, 8,785 C files, plus build/test support.
- Existing external audits reviewed:
  - `outputs/hsgram_feature_audit/HSgram_Telegram功能差距四端扫描_2026-05-24.xlsx`
  - `outputs/hsgram_scan_report/HSgram_未实现空实现半实现与Bug扫描报告.xlsx`
  - `outputs/hsgram_client_server_flow_audit/HSgram_客户端服务端功能链路真实测试结论_2026-05-26.xlsx`

## Old iOS Module Map

The old app is a large Telegram fork. The highest-signal modules for native parity are:

| Feature Surface | Old Source Modules | Native Rebuild Target |
| --- | --- | --- |
| App shell and auth | `Telegram/Telegram-iOS`, `AuthorizationUI`, `AuthorizationUtils`, `AccountContext`, `AccountUtils` | Email-only auth, session handling, App Store-safe app shell |
| Chat list and folders | `ChatListUI`, `TelegramCore/Sources/TelegramEngine/Messages/ChatList.swift`, `ChatListFilterSettingsHeaderItem`, `ArchivedStickerPacksNotice` | Dialogs, unread state, pinned/archived/folders, saved messages |
| Chat thread | `TelegramUI/Components/Chat/*`, `ChatInterfaceState`, `ChatPresentationInterfaceState`, `ListMessageItem` | History, read state, replies, edits, deletes, forwards, reactions, pins, drafts |
| Composer and attachments | `AttachmentUI`, `AttachmentTextInputPanelNode`, `MediaPickerUI`, `LegacyMediaPickerUI`, `Camera`, `GalleryUI`, `DrawingUI` | Photo/video/document sending, captions, albums, camera, pasteboard |
| Stickers, emoji, reactions | `FeaturedStickersScreen`, `StickerPackPreviewUI`, `ReactionSelectionNode`, `Emoji`, `TelegramAnimatedStickerNode` | Sticker packs, emoji, reaction picker, recent/favorites |
| Contacts and profiles | `ContactListUI`, `ContactsHelper`, `ContactsPeerItem`, `PeerInfoUI`, `PeerAvatarGalleryUI` | Contacts, requests, block/unblock, profile view, avatars |
| Groups, channels, invites | `InviteLinksUI`, `SearchPeerMembers`, `PeerInfoUI`, `TelegramUI/Components/PeerManagement/*` | Supergroup/channel create/manage, members, admins, restrictions, invite links, join requests |
| Search and shared media | `SearchUI`, `ChatHistorySearchContainerNode`, `CalendarMessageScreen`, `HashtagSearchUI`, `WebSearchUI` | Global search, chat search, media/link/file filters |
| Settings and privacy | `SettingsUI`, `NotificationMuteSettingsUI`, `NotificationSoundSelectionUI`, `PasscodeUI`, `PasswordSetupUI`, `AppLock` | Profile, privacy/security, notifications, devices, local lock, storage |
| Notifications and extensions | `NotificationService`, `NotificationContent`, `Share`, `SiriIntents`, `WidgetKitWidget`, `Watch` | APNs token registration, rich notifications, share extension parity where required |
| Trust/business/admin tools | `PremiumUI`, `StatisticsUI`, `BotPaymentsUI`, `DebugSettingsUI`, business/passkey paths from audits | Merged HSgram advanced surface without paid-tier split |

Deferred for first rebuilt submission: voice calls, group voice/video chat, live streaming, and related call/live UI modules (`TelegramCallsUI`, `TelegramVoip`, `TgVoipWebrtc`, live camera streaming paths).

## Feature Audit Baseline

Existing cross-repo feature audit categories:

| Category | Total | Implemented | Partial | Fake | Missing |
| --- | ---: | ---: | ---: | ---: | ---: |
| Groups | 55 | 51 | 0 | 4 | 0 |
| Media/files/stickers | 54 | 33 | 17 | 4 | 0 |
| Private chats/messages/text | 52 | 39 | 6 | 5 | 2 |
| Channels | 45 | 21 | 12 | 11 | 1 |
| Bots/Mini Apps/developer platform | 43 | 13 | 19 | 11 | 0 |
| Premium | 36 | 0 | 0 | 36 | 0 |
| Stars/gifts/monetization | 36 | 0 | 0 | 31 | 5 |
| Privacy/security/content protection | 35 | 14 | 18 | 1 | 2 |
| Account/login/contacts/profile | 34 | 13 | 18 | 3 | 0 |
| UI/customization/cross-platform | 29 | 20 | 7 | 1 | 1 |
| Search/organization/storage/notifications | 28 | 24 | 4 | 0 | 0 |
| Stories | 22 | 0 | 0 | 18 | 4 |
| Business | 19 | 16 | 1 | 2 | 0 |

Product decision for this native rebuild:

- Keep email-only sign-in for App Store review.
- Create new groups as supergroups.
- Use the same server state and sync paths as Android/PC/iOSM.
- Merge premium and enterprise/admin capabilities into one HSgram surface unless payment/business logic is explicitly out of scope.
- Hide or defer fake paid/Stars/Stories surfaces until server state is real enough to verify.

## Native Coverage So Far

Implemented in the native rebuild:

- Email auth with split email/code entry, HSgram-style code-card UI, old sign-up profile fields for first name, last name, and invite code, native MTProto `auth.sendCode`/`auth.signIn`/`auth.signUp`, login-password SRP handling, login-password setup/change/remove through `account.updatePasswordSettings`, recovery-email confirm/resend/cancel, old-style recovery-code login through `auth.requestPasswordRecovery` / `auth.recoverPassword`, and Keychain-backed session persistence.
- Main tabs, workspace summary, dialogs, contacts, channels, settings, trust center, advanced tools; circle-specific surfaces remain paused by current product scope.
- Saved Messages self-chat entry and forward target, following the old `context.account.peerId` saved-dialog behavior.
- Message history, load-older pagination, read refresh.
- Text send, reply send, left-swipe reply, reply reference preview/jump, server-backed drafts with reply target restore, edit, delete, forward, reactions, supergroup pins, message links, URL taps, and mention/hashtag taps into chat search.
- Photo/video/file/voice-message sending via existing MTProto upload/save-file-part, `inputMediaUploadedPhoto`, `inputMediaUploadedDocument`, and `messages.sendMedia`; video uses `documentAttributeVideo`, voice uses `documentAttributeAudio` with the voice flag and packed waveform bytes, GIF uses `documentAttributeAnimated`, and generic files use force-file behavior.
- Native camera capture is wired from the attachment menu for photo/video capture and reuses the same MTProto media upload path; simulator builds gracefully report camera unavailable.
- Received photo/document media metadata now parses from MTProto `messageMediaPhoto` and `messageMediaDocument` into native message bubbles, including photo/video/GIF/audio/file/sticker type, filename, mime, size, dimensions, and duration where present.
- Historical link previews now parse from MTProto `messageMediaWebPage` / `WebPage`, keep URL/display URL/site/title/description/embed metadata, consume cached Instant View pages and webpage attributes safely, and render native link-preview bubbles plus shared-links rows. Composer-side live previews now use existing `messages.getWebPagePreview`, and dismissing the composer preview sends/saves the draft with `no_webpage`.
- Media upload/download now reports native transfer progress, supports cancel from the chat UI, keeps failed upload payloads retryable, and retries failed downloads from the media card.
- Received media can now download through existing MTProto `upload.getFile` with `inputPhotoFileLocation` / `inputDocumentFileLocation`, reuse files from the app Caches directory, preview images/video/audio/voice messages, render voice waveforms, share/open other downloaded files, expose local media cache size/clear plus keep-duration/size-limit eviction controls in Data & Storage settings, and pre-cache eligible chat media through local Wi-Fi/cellular low/medium/high/custom auto-download settings with contacts/private/group/channel source filters, old size steps, video preload state, Stories preference parity, and old-style energy-saving/background autodownload gating.
- Global search across dialogs, contacts, and messages.
- Dialog list parity now keeps manual unread marks, pinned state, and muted state from dialog flags, marks chats read/unread through existing `messages.readHistory` and `messages.markDialogUnread`, pins/unpins chats through existing `messages.toggleDialogPin`, reorders pinned chats through existing `messages.reorderPinnedDialogs`, counts manual marks in the Unread filter, loads the Archived filter with `messages.getDialogs(folder_id: 1)`, archives/unarchives chats through existing `folders.editPeerFolders`, and manages server chat folders through native `messages.getDialogFilters` / `messages.updateDialogFilter` / `messages.updateDialogFiltersOrder` / `messages.toggleDialogFilterTags` with include/exclude/pinned/category matching in the Chats tab.
- Foreground interoperability now includes a native MTProto state poller following the old `AccountStateManager` shape: bootstrap with `updates.getState`, poll `updates.getDifference`, persist the last update state per account, parse common message/reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat updates into affected dialog refresh signals, and refresh dialogs/open threads when differences or too-long states are detected.
- Chat search inside one dialog, based on the old `ChatHistorySearchContainerNode` / `ChatControllerUpdateSearch` remote peer-message search flow, with result list selection and jump-to-message loading through existing history pagination.
- Shared media browser for media, files, links, GIF, voice, and music, using existing MTProto `messages.search` with `inputMessagesFilterPhotoVideo`, `inputMessagesFilterDocument`, `inputMessagesFilterUrl`, `inputMessagesFilterGif`, `inputMessagesFilterRoundVoice`, and `inputMessagesFilterMusic`; rows page by `offset_id`, tab counts come from old-iOS `messages.getSearchCounters`, and rows jump back into the loaded chat thread.
- Contact search, request, accept, decline, delete, block, unblock, and blocked-users list management.
- Contact profile screen from contacts, search results, and private chats, with message/request/accept/decline/delete/block/unblock actions on existing contact APIs.
- Supergroup/channel creation, details, members/subscribers, invite links, admin promotion, restrictions/settings, admin logs.
- Profile, privacy summary, privacy base rules plus Always Allow/Never Allow peer exceptions through existing `account.setPrivacy`, blocked users management, notification scopes, storage summary, device reset, and account deletion through existing `account.deleteAccount`.
- Appearance, language, and support settings entries based on old `ThemeSettingsController`, localization list, and FAQ/support flow; deeper theme assets and localization resource migration remain.
- Local passcode/app lock now mirrors the old passcode surface for 4/6-digit numeric passcodes, old auto-lock choices, Face ID/Touch ID unlock, biometric domain-state validation, failed-attempt throttling, app-switcher privacy cover, and Keychain-backed passcode storage with legacy UserDefaults migration.
- APNs token registration, device push permission UI, foreground presentation, remote-notification background mode, badge clearing, and push-triggered Today/dialog/thread refresh.
- App Store privacy hardening resources: explicit HSgram `Info.plist` permission strings and bundled `PrivacyInfo.xcprivacy` for collected account/content/media data plus UserDefaults required-reason API use.

## Implementation Order

Work through this list by module, updating this file, `FULL_MIGRATION_MATRIX.md`, and `MODULE_MIGRATION_PLAN.md` as each module is implemented and verified. The active module order is Settings, private chats, groups, channels, contacts, then media/stickers and notification extensions.

Before implementing a module, read the matching old `HSgram_ios` source paths from `MODULE_MIGRATION_PLAN.md`, then align the native files to that module boundary. Do not make server changes while doing this migration; if an old behavior needs a missing server contract, record it as a native TODO for approval instead.

1. Messaging parity
   - Server-backed drafts: save, clear, restore, show draft badge in chat list. Done.
   - Media send: photo, video, document, captions, upload progress. Must use existing server/API paths; do not add new server endpoints.
     Photo/video/file/voice-message send and captions now use the existing MTProto media path; received-media metadata rendering, basic download/preview, progress, cancel, retry UI, cache reuse, Settings cleanup, old-style automatic local cache eviction, and local auto-download controls/pre-cache with source filters, custom sizes, Stories preference parity, and energy-saving/background gating are in place; CDN redirects and actual Stories message/server surfaces remain.
   - Shared media browser: media, files, links, GIF, voice, and music. Done for native MTProto filters, server counters through `messages.getSearchCounters`, paging, jump-to-message, link-preview rows, and media/GIF grid phases; thumbnail-backed cells and old calendar parity remain.
   - Chat search inside one dialog. Native parity follows the old remote peer-message search/list/jump flow with inline search state, result count, previous/next navigation, and result list entry; final visual pass should match the old navigation-bar placement and panel styling.
   - Pinned, archived, and custom folder chats. Done for native pinned flag parsing, muted-state parsing, pin indicators, pinned-first ordering, pin/unpin actions, pinned drag reorder, Archived filter/list loading, context-menu archive/unarchive actions, and server-backed custom folder tabs plus create/edit/delete/reorder/tag-display management through existing MTProto dialog/folder APIs; shared folder links, tag-color polish, and final visual parity remain.
   - Realtime/difference refresh. Done for foreground `updates.getState` / `updates.getDifference` polling, common non-message/reaction/profile/member/notify/privacy update parsing, nested collectible emoji status and channel participant rank parsing, affected-dialog UI refresh signaling, typing no-op handling, and unsupported-shape full-refresh fallback; durable local application of every update constructor and socket/background streaming remain.
   - Unread separator. Done for the old `ChatUnreadItem` behavior: opening a dialog uses the pre-read unread count, loads earlier history when needed to avoid a guessed boundary, inserts a native unread bar before the first unread message, scrolls there first, then uses existing read-history APIs.
   - Mentions, hashtags, historical and composer link previews, copy/share links.
     Server-returned `messageMediaWebPage` is now decoded and rendered in native chat bubbles/shared link rows; live composer preview fetching uses `messages.getWebPagePreview`, with dismissed previews persisted through `no_webpage` on send/draft.
   - Saved messages entry and self-chat semantics. Done for chat list entry, open self-chat, and forward target using the current account id.

2. Contacts and profiles
   - Full profile screen from contact/chat/user. Done for contact list, search user result, and private-chat info using existing contact APIs.
   - Avatar/photo viewing and update path.
   - Address-book import/share invite flow, if still desired for App Store privacy.
   - Report/block flows connected to trust/moderation state.

3. Groups and channels
   - Join-request queue and approval/decline UI.
   - Rules/acknowledgement UI.
   - Member search, admin rights editor completeness, banned user list.
   - Channel posting controls and subscriber/admin edge cases.

4. Media and stickers
   - Attachment picker and camera capture. Done for gallery/file picker plus native camera photo/video capture; albums, pasteboard, drawing/editor tools remain.
   - Image/video/document upload through shared media backend.
   - Sticker pack list/install/favorites/recent.
   - Reaction picker with available reactions from server.

5. Settings and account security
   - Module boundary split is in place: settings home, profile, appearance, language, privacy, notifications, data/storage, support, devices, and advanced tools now live in separate native files. The visible settings home is now aligned to the old `PeerInfoSettingsItems` root grouping: account/trust/privacy, chat workflows with Favorites, Devices, and Chat Folders, experience preferences, support, logout, and delete-account.
   - Privacy base-rule editing and per-peer Always Allow/Never Allow exception editors now use existing `account.setPrivacy`.
   - Chat Folders are reachable from Settings and reuse the same existing MTProto folder APIs as the Chats tab: `messages.getDialogFilters`, `messages.updateDialogFilter`, `messages.updateDialogFiltersOrder`, and `messages.toggleDialogFilterTags`.
   - Account deletion UI with confirmation and server path. Done through existing `account.deleteAccount`, including optional SRP password proof.
   - Local app lock/passcode/biometric lock. Done for 4/6-digit numeric passcodes, auto-lock choices, Face ID/Touch ID, biometric domain-state validation, failed-attempt throttling, app-switcher cover, and Keychain-backed passcode storage with legacy UserDefaults migration.
   - Passkey management if it remains part of HSgram parity.
   - Appearance/language/help/support screens. Native entries are in place with color scheme, text size, locale preference, and FAQ/support links; remaining work is full old theme carousel, app icons, wallpapers, and localization packs.

6. Notifications and extensions
   - APNs token registration and server storage are wired through `account.registerDevice`; device-side entitlement, delegate, categories, foreground presentation, manual sync, and badge clear are in the native target.
   - Foreground/background update handling. Done for APNS event relay into Today/dialog/thread refresh; notification service/content extensions remain.
   - Rich notification handling if needed.
   - Share extension / Siri / widget / watch parity decision.

7. Advanced/business/admin
   - Business quick replies, greeting/away/start page if product keeps them.
   - Admin/circle operational tools from existing backend.
   - Statistics and moderation review surfaces.

8. App Store hardening
   - Remove Telegram-derived binary/assets/strings from target.
   - Privacy manifest and permission descriptions are bundled; final icons, screenshots, review metadata, and archive-time scans remain.
   - Reviewer account flow using email only.
   - End-to-end Android/PC/iOSM/native-iOS interoperability verification.

## Approval Notes

- The old chat search has an inline navigation search bar plus a bottom result navigation panel (`ChatSearchNavigationContentNode`, `ChatTagSearchInputPanelNode`). The native version now uses the same search state, count, previous/next navigation, result list entry, and jump-to-message behavior. The remaining difference is visual placement/styling, which should be handled in the final UI parity pass instead of treated as an approved redesign.

## Verification Rule

Each migrated feature needs:

- Native iOS UI entry.
- Typed native API client method.
- Server facade endpoint or direct existing endpoint.
- Backend writes/reads through shared HSgram/Teamgram state.
- Focused build/test evidence.
- Cross-platform behavior noted where possible.
