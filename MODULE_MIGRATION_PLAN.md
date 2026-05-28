# HSgram Native iOS Module Migration Plan

This plan keeps the rebuild aligned to the old `HSgram_ios` app by module instead of scattered feature patches. The native app must keep using the existing HSgram server/API contract; server source stays read-only unless a backend change is explicitly approved.

## Module Rules

- Implement one module surface at a time: Settings, private chats, groups, channels, contacts, media/stickers, notifications/extensions, App Store hardening.
- For every module, read the old `HSgram_ios` source paths listed below before implementing the native behavior.
- Preserve old user-facing behavior first; UI polish and any product simplification go into an approval note before changing behavior.
- Voice calls, video chat, group calls, and live streaming remain deferred.
- If an old feature needs server state that the current native API does not expose, add a client TODO and record the missing contract. Do not edit server code.

## 1. Auth Module

Native boundary:

- `HSgramNative/Auth/AuthStore.swift`
- `HSgramNative/Auth/AuthView.swift`
- `HSgramNative/Auth/AuthSessionStore.swift`
- `HSgramNative/Networking/HSAPIClient.swift`

Old source references:

- `submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceEmailEntryController.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceEmailEntryControllerNode.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceSignUpController.swift`
- `submodules/AuthorizationUtils/Sources/AuthorizationLayout.swift`
- `submodules/AccountContext`

Native status:

- Email-only sign-in/register UI exists and default production transport now matches old `HSgram_ios`: native MTProto `auth.sendCode` with the email as the login identifier, followed by `auth.signIn`/`auth.signUp`, and `account.getPassword`/SRP when the server returns `SESSION_PASSWORD_NEEDED`.
- The old `/v1/auth/email/start` and `/v1/auth/email/verify` facade is not deployed on `hsgram.cloud`; native `/v1` calls are disabled by default and only enabled for explicit local bridge testing with `HS_NATIVE_REST_BRIDGE=1`.
- Auth UI is split into old-style email entry, HSgram-style code card, login-password, recovery-code, and sign-up profile steps, with masked target text, resend/back handling, first name, last name, and invite-code registration fields matching the old AuthorizationUI structure.
- Native sessions are persisted in iOS Keychain as both the current account and a saved account list, matching the old app's durable multi-account behavior without adding server endpoints.
- Existing accounts that require the old Telegram-style login password now use native `account.getPassword`/SRP `auth.checkPassword` instead of surfacing a generic verification failure.
- The old password recovery entry is wired in native UI: “forgot security password” requests a recovery code with `auth.requestPasswordRecovery`, submits it through `auth.recoverPassword`, and saves the returned MTProto session without adding server endpoints.
- Login-password setup/change/remove is wired through existing `account.updatePasswordSettings`, including recovery-email confirm/resend/cancel with `account.confirmPasswordEmail`, `account.resendPasswordEmail`, and `account.cancelPasswordEmail`.
- Server-supplied `help.TermsOfService` from `auth.authorizationSignUpRequired` is parsed and shown during sign-up, including popup confirmation and `min_age_confirm`, before continuing through the existing `auth.signUp` path.
- Sign-up avatar selection now follows the old AuthorizationUI order: compress the selected image locally, complete `auth.signUp`, then call existing MTProto `photos.uploadProfilePhoto`; avatar upload errors do not block account creation, matching old iOS behavior.
- Remaining parity: Apple Sign In if product keeps it, support-email helper flows, account-count/premium-limit enforcement, review-account login-password/recovery E2E, and richer localized error mapping. Do not edit server source unless explicitly approved.

## 2. Settings Module

Native boundary:

- `HSgramNative/Settings/SettingsView.swift`
- `HSgramNative/Settings/ProfileSettingsView.swift`
- `HSgramNative/Settings/DeleteAccountView.swift`
- `HSgramNative/Settings/AppearanceSettingsView.swift`
- `HSgramNative/Settings/LanguageSettingsView.swift`
- `HSgramNative/Settings/PrivacySettingsView.swift`
- `HSgramNative/Settings/BlockedUsersView.swift`
- `HSgramNative/Settings/NotificationSettingsView.swift`
- `HSgramNative/Settings/DataStorageSettingsView.swift`
- `HSgramNative/Settings/SupportSettingsView.swift`
- `HSgramNative/Settings/DevicesView.swift`
- `HSgramNative/Settings/AdvancedToolsView.swift`
- `HSgramNative/Settings/LogoutOptionsView.swift`
- `HSgramNative/Settings/PasscodeStore.swift`
- `HSgramNative/Settings/PasscodeLockView.swift`
- `HSgramNative/Settings/PasscodeSettingsView.swift`

Old source references:

- `submodules/SettingsUI/Sources/SettingsController.swift`
- `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift`
- `submodules/SettingsUI/Sources/Privacy and Security/PrivacyAndSecurityController.swift`
- `submodules/SettingsUI/Sources/Privacy and Security/PasscodeOptionsController.swift`
- `submodules/PasscodeUI/Sources/PasscodeEntryController.swift`
- `submodules/PasscodeUI/Sources/PasscodeSetupController.swift`
- `submodules/AppLock/Sources/AppLock.swift`
- `submodules/SettingsUI/Sources/Notifications/NotificationsAndSoundsController.swift`
- `submodules/SettingsUI/Sources/Data and Storage/DataAndStorageSettingsController.swift`
- `submodules/SettingsUI/Sources/Themes/ThemeSettingsController.swift`
- `submodules/SettingsUI/Sources/Language Selection/LocalizationListController.swift`
- `submodules/SettingsUI/Sources/DeleteAccountOptionsController.swift`
- `submodules/SettingsUI/Sources/LogoutOptionsController.swift`

Native status:

- Settings shell and page boundaries are split. The settings root now follows the old `PeerInfoSettingsItems` grouping instead of native-only sections: account/trust/privacy, chat workflows with Favorites, Devices, and Chat Folders, experience preferences, support, logout, and delete-account.
- Profile now loads the current user through existing `users.getFullUser(inputUserSelf)` instead of local session guessing, including server `about` and username from the returned users vector; Today/workspace summary now aggregates from existing MTProto dialogs, contacts, and account authorizations instead of the old `/v1` draft route; saved account switcher/add-account entry, Favorites self-chat entry, devices, server-backed chat folder management, privacy summary, base privacy-rule editing, per-peer privacy exception editors, blocked users list/unblock, notifications, storage, appearance, language, support, account deletion, and old-style logout options entries exist.
- Profile avatar update/removal now matches the old `PeerPhotoUpdater` route: local image compression plus existing `photos.uploadProfilePhoto` for new photos, and `photos.updateProfilePhoto` with `inputPhotoEmpty` for removing the current photo.
- Local passcode/app lock now supports enable, change, disable, 4/6-digit numeric passcodes, manual lock, scene-phase auto-lock, the old auto-lock timeout choices, Face ID/Touch ID unlock, biometric domain-state validation, 6-failure/1-minute retry throttling, an app-switcher privacy cover, and Keychain-backed passcode storage with legacy UserDefaults migration.
- Account deletion now exists through `account.deleteAccount`, with confirmation, optional SRP password proof, and local session/auth-key cleanup after server confirmation.
- Remaining parity: old premium account-count limit UI, change email/phone migration flow, dedicated Tips/HSgram features content, separate Power Saving surface instead of the current data/storage-backed entry, share-extension lock state if extensions are restored, notification exceptions/sounds, actual Stories message/server surfaces, theme carousel, wallpapers, app icon choices, full localization packs.

## 3. Private Chat Module

Native boundary:

- `HSgramNative/Chats/ChatListView.swift`
- `HSgramNative/Chats/ChatListFilterBar.swift`
- `HSgramNative/Chats/ChatThreadView.swift`
- `HSgramNative/Chats/ChatComposerView.swift`
- `HSgramNative/Chats/MessageBubbleView.swift`
- `HSgramNative/Chats/ChatThreadSearchViews.swift`
- `HSgramNative/Chats/ForwardDialogSheet.swift`
- `HSgramNative/Chats/ChatAttachmentSheet.swift`
- `HSgramNative/Chats/MessageSelectionToolbar.swift`
- Future split: message action polish, media picker internals, upload/send adapters, and shared media.

Old source references:

- `submodules/ChatListUI`
- `submodules/TelegramUI/Components/Chat`
- `submodules/TelegramUI/Sources/ChatController.swift`
- `submodules/TelegramUI/Sources/ChatControllerUpdateSearch.swift`
- `submodules/TelegramUI/Sources/ChatHistorySearchContainerNode.swift`
- `submodules/TelegramUI/Sources/ChatSearchNavigationContentNode.swift`
- `submodules/TelegramCore/Sources/TelegramEngine/Messages/ChatList.swift`
- `submodules/AttachmentUI`
- `submodules/MediaPickerUI`

Native status:

- Chat list and thread boundaries are split for folder-style filters, old iOS-style 75pt chat-list rows, the thread container, composer/reply accessory panel, attachment menu shell, message bubble/reply reference, in-chat search views, forward target sheet, and message selection toolbar.
- Private-chat clear history, delete chat, and delete for both now use the existing server/old-iOS `messages.deleteHistory` semantics (`just_clear`, `revoke`, and top-message `max_id`) through the native MTProto transport.
- Private-chat in-thread search now follows old iOS peer-scoped search: the UI calls the native facade route for the current dialog, which maps to existing server `messages.search` with `inputMessagesFilterEmpty`, remote result navigation, and jump-to-message behavior instead of global-search filtering.
- Private-chat input activity now follows old iOS `messages.setTyping`: typing, voice recording, media/file/voice upload progress, cancel, and choosing-sticker actions are represented in the native model, sent through the current MTProto peer, parsed from `updateUserTyping` / chat / channel typing updates, and shown transiently in the chat header without triggering list-wide refreshes.
- Dialogs, old-style All/Unread/Contacts/Groups/Archived filtering, chat-list row layout with 60pt avatars, right-aligned time, top-line outgoing sending/failed/sent/read status icons from local send state plus top-message/read-outbox state, title mute icon, bottom-right unread/marked-unread/pinned accessories, pinned row background, mark-read/mark-unread swipe actions, pinned/archived state, pinned drag reorder, text history, pagination, unread separator with first-unread initial scroll, per-day chat date separators, adjacent same-author bubble grouping with merged tails/corners, outgoing sending/failed/single/double-check receipts backed by local text/media-send pending/failed retry states plus existing MTProto `readOutboxMaxId` / `messages.getPeerDialogs` and `updateReadHistoryOutbox` / `updateReadChannelOutbox` sync updates, text sending, edit/delete/forward/reactions/pins, parsed/rendered message reaction counts with optimistic reaction feedback, edited-message labels, channel author signatures, channel post view/reply counters in the bubble status row, replies, left-swipe reply, reply preview/jump, message links, URL taps, mention/hashtag taps into chat search, server drafts, saved messages, in-chat search, multi-select copy/forward/delete, APNS refresh, and foreground MTProto `updates.getState` / `updates.getDifference` refresh signaling exist, including affected-dialog refresh for common reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat updates.
- Server-backed chat folders now use native MTProto `messages.getDialogFilters`, `messages.updateDialogFilter`, `messages.updateDialogFiltersOrder`, and `messages.toggleDialogFilterTags` through the existing transport facade. The Chats tab appends custom folder tabs from the server, applies old iOS-style include/exclude/pinned/category matching using parsed dialog peer metadata, and includes native folder management for create, edit, delete, drag reorder, and tag-display toggling.
- Attachment menu options now mirror the old `AttachmentButtonType` surface for gallery, file, location, contact, poll, todo, and quick reply.
- Remaining parity: durable local update application, socket/background update streaming, albums/pasteboard/editor tools, thumbnail-backed shared-media cells, old calendar parity, share/action-sheet polish, shared folder invite links, tag-color visual polish, and final folder UI parity styling. Historical server-returned `messageMediaWebPage` previews now parse/render in chat bubbles/shared-link rows, composer-side live previews use existing `messages.getWebPagePreview` with `no_webpage` dismissal on send/draft, and shared media browsing now exposes media/files/links/GIF/voice/music filters through existing `messages.search` with tab counters from old-iOS `messages.getSearchCounters`.
- Production message transport now maps `HSAPIClient.sendMessage` through `HSDeployedServerTransport` / `HSNativeServerTransport` into native MTProto `messages.sendMessage`, so text messages no longer depend on the undeployed `/v1` REST facade. Media sends already route through the existing native MTProto upload + `messages.sendMedia` path. Do not edit server source unless explicitly approved.

## 4. Groups Module

Native boundary:

- `HSgramNative/Groups/NewSupergroupSheet.swift`
- `HSgramNative/Groups/SupergroupManageView.swift`
- `HSgramNative/Groups/MemberSearchSupport.swift`
- `HSgramNative/Groups/AdminRightsEditorSheet.swift`
- `HSgramNative/Groups/MemberRestrictionsEditorSheet.swift`
- `HSgramNative/Groups/SupergroupSettingsEditorSheet.swift`
- `HSgramNative/Groups/InviteLinkOptionsSheet.swift`
- Entry points remain in `HSgramNative/Chats/ChatListView.swift` for new group creation and `HSgramNative/Chats/ChatThreadView.swift` for group info.
- Future split: group list refinements, members, admin rights, restrictions, invite links, join requests, rules, admin log.
- Circle-specific product surfaces are paused, not exposed in the main tab bar, and should not be expanded in this migration pass.

Old source references:

- `submodules/PeerInfoUI/Sources/ChannelMembersController.swift`
- `submodules/PeerInfoUI/Sources/ChannelAdminController.swift`
- `submodules/PeerInfoUI/Sources/ChannelAdminsController.swift`
- `submodules/PeerInfoUI/Sources/ChannelPermissionsController.swift`
- `submodules/PeerInfoUI/Sources/ChannelBlacklistController.swift`
- `submodules/PeerInfoUI/Sources/ChannelBannedMemberController.swift`
- `submodules/PeerInfoUI/Sources/GroupPreHistorySetupController.swift`
- `submodules/InviteLinksUI`
- `submodules/SearchPeerMembers/Sources/SearchPeerMembers.swift`
- `submodules/TelegramCore/Sources/ApiUtils/HSGroup.swift`
- `submodules/TelegramCore/Sources/ApiUtils/HSChannelAdminRights.swift`
- `submodules/TelegramCore/Sources/ApiUtils/HSChannelBannedRights.swift`

Native status:

- Groups module boundary is in place for supergroup creation, supergroup management, and shared member-search matching.
- Supergroup creation, detail edit, member list, local member search by name/username/role, shared contact invite picker, remove member, delete member history, configurable admin rights editor, configurable member restrictions with media sub-permissions/duration, group settings editor for slow mode/join-to-send/join requests/pre-history/member list visibility, configurable invite link generation, admin log, and message pins exist.
- Remaining parity: join-request queue, rules acknowledgement, remote/transliterated member search, banned/restricted user lists, default group-permission editor polish.

## 5. Channels Module

Native boundary:

- `HSgramNative/Channels/ChannelsView.swift`
- `HSgramNative/Channels/ChannelManageView.swift`
- Future split: channel visibility/public link controls, discussion group linkage, posting controls, subscriber/admin edge cases, and stats.

Old source references:

- `submodules/PeerInfoUI/Sources/ChannelMembersController.swift`
- `submodules/PeerInfoUI/Sources/ChannelAdminsController.swift`
- `submodules/PeerInfoUI/Sources/ChannelVisibilityController.swift`
- `submodules/PeerInfoUI/Sources/ChannelDiscussionGroupSetupController.swift`
- `submodules/PeerInfoUI/Sources/ChannelPermissionsController.swift`
- `submodules/InviteLinksUI`
- `submodules/TelegramCore/Sources/ApiUtils/HSChannel.swift`
- `submodules/StatisticsUI/Sources/ChannelStatsController.swift`

Native status:

- Channel module boundary is in place for channel list/create/open chat plus channel detail/subscribers/admins/invite links/admin log.
- Channel list/create/open chat, create-time contact subscriber selection, detail edit, subscriber list, local subscriber search by name/username/role, contact invites, subscriber removal, configurable admin rights editor, configurable invite link generation, and admin log exist.
- Remaining parity: discussion group linkage, public/private visibility controls, remote/transliterated subscriber/admin search, subscriber/admin edge cases, channel stats if product keeps them.

## 6. Contacts Module

Native boundary:

- `HSgramNative/Contacts/ContactsView.swift`
- `HSgramNative/Contacts/AddContactSheet.swift`
- `HSgramNative/Contacts/ContactProfileView.swift`
- `HSgramNative/Contacts/ContactRow.swift`
- `HSgramNative/Contacts/ContactInvitePickerSheet.swift`
- Future split: address-book import, invite contacts, avatar gallery, report actions, and richer device-contact sections.

Old source references:

- `submodules/ContactListUI`
- `submodules/ContactsHelper`
- `submodules/PeerInfoUI/Sources/UserInfoController.swift`
- `submodules/PeerInfoUI/Sources/DeviceContactInfoController.swift`
- `submodules/PeerInfoUI/Sources/PeerAvatarGalleryUI`

Native status:

- Contacts module boundary is in place for the contacts list, add/search/request sheet, profile actions, reusable contact row, and shared contact invite picker.
- Contacts list, user search, profile view, message entry, request, accept, decline, delete, block, and unblock exist.
- Remaining parity: avatar viewing/update, address-book import/invite, report flow, richer profile sections.
