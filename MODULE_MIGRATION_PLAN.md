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
- `submodules/TelegramCore/Sources/Wallpapers.swift`
- `submodules/TelegramCore/Sources/ApiUtils/Wallpaper.swift`
- `submodules/SettingsUI/Sources/Language Selection/LocalizationListController.swift`
- `submodules/SettingsUI/Sources/DeleteAccountOptionsController.swift`
- `submodules/SettingsUI/Sources/LogoutOptionsController.swift`

Native status:

- Settings shell and page boundaries are split. The settings root now follows the old `PeerInfoSettingsItems` grouping instead of native-only sections: account/trust/privacy, chat workflows with Favorites, Devices, and Chat Folders, experience preferences, support, logout, and delete-account.
- Profile now loads the current user through existing `users.getFullUser(inputUserSelf)` instead of local session guessing, including server `about` and username from the returned users vector; Today/workspace summary now aggregates from existing MTProto dialogs, contacts, and account authorizations instead of the old `/v1` draft route; saved account switcher/add-account entry, Favorites self-chat entry, devices, server-backed chat folder management, privacy summary, base privacy-rule editing, per-peer privacy exception editors, blocked users list/unblock, notifications, storage, appearance, language, support, account deletion, and old-style logout options entries exist.
- Profile avatar update/removal now matches the old `PeerPhotoUpdater` route: local image compression plus existing `photos.uploadProfilePhoto` for new photos, and `photos.updateProfilePhoto` with `inputPhotoEmpty` for removing the current photo.
- Local passcode/app lock now supports enable, change, disable, 4/6-digit numeric passcodes, manual lock, scene-phase auto-lock, the old auto-lock timeout choices, Face ID/Touch ID unlock, biometric domain-state validation, 6-failure/1-minute retry throttling, an app-switcher privacy cover, and Keychain-backed passcode storage with legacy UserDefaults migration.
- Account deletion now exists through `account.deleteAccount`, with confirmation, optional SRP password proof, and local session/auth-key cleanup after server confirmation.
- Wallpaper catalog/detail/save/install/reset is protocol/facade-ready through existing server MTProto `account.getWallPapers`, `account.getWallPaper`, `account.saveWallPaper`, `account.installWallPaper`, and `account.resetWallPapers`, including file, solid/gradient, and emoticon/no-file wallpaper inputs; UI remains mock-driven until the appearance branch is ready.
- Notification exceptions/sounds/reset and saved/uploaded ringtones are protocol/facade-ready through existing server MTProto `account.getNotifyExceptions`, `account.resetNotifySettings`, `account.getSavedRingtones`, `account.saveRingtone`, and `account.uploadRingtone`; UI remains mock-driven until the notifications screen branch is ready.
- Language pack list/preview/full-pack/string/difference sync is protocol/facade-ready through existing server MTProto `langpack.getLanguages`, `langpack.getLanguage`, `langpack.getLangPack`, `langpack.getStrings`, and `langpack.getDifference`; UI remains mock-driven and broader copy migration can wait for the localization pass.
- Remaining parity: old premium account-count limit UI, change email/phone migration flow, dedicated Tips/HSgram features content, separate Power Saving surface instead of the current data/storage-backed entry, share-extension lock state if extensions are restored, actual Stories message/server surfaces, theme carousel UI, wallpaper UI wiring, app icon choices, full hard-coded copy localization coverage.

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
- Dialogs, old-style All/Unread/Contacts/Groups/Archived filtering, chat-list row layout with 60pt avatars, right-aligned time, top-line outgoing sending/failed/sent/read status icons from local send state plus top-message/read-outbox state, title mute icon, bottom-right unread/marked-unread/pinned accessories, pinned row background, mark-read/mark-unread swipe actions, pinned/archived state, pinned drag reorder, text history, pagination, unread separator with first-unread initial scroll, per-day chat date separators, adjacent same-author bubble grouping with merged tails/corners, outgoing sending/failed/single/double-check receipts backed by local text/media-send pending/failed retry states plus existing MTProto `readOutboxMaxId` / `messages.getPeerDialogs` and `updateReadHistoryOutbox` / `updateReadChannelOutbox` sync updates, message-content read service actions through existing `messages.readMessageContents` for private/basic group media/mention/reaction consume state, text sending, edit/delete/forward/reactions/pins, parsed/rendered message reaction counts with optimistic reaction feedback, reaction detail list service through old-iOS/server `messages.getMessageReactionsList#461b3f48`, edited-message labels, channel author signatures, channel post view/reply counters in the bubble status row plus refresh service through `messages.getMessagesViews`, group/channel read participant snapshots through old-iOS `messages.getMessageReadParticipants#31c1c44f`, replies, left-swipe reply, reply preview/jump, message links, URL taps, mention/hashtag taps into chat search, server drafts, saved messages, in-chat search, multi-select copy/forward/delete, APNS refresh, and foreground MTProto `updates.getState` / `updates.getDifference` refresh signaling exist, including affected-dialog refresh for common reaction/profile/member/notify/privacy/read/delete/draft/pin/folder/filter/channel/chat updates. Mark-read, clear-history, and delete now follow old iOS peer splitting: private/basic groups use `messages.readHistory` / `messages.deleteHistory` / `messages.deleteMessages`, while channels/supergroups use `channels.readHistory` / `channels.deleteHistory` / `channels.deleteMessages`. The current UI branch is mock-driven, so new service calls are protocol/facade-ready but not UI-wired in this pass.
- Reaction picker cloud state now follows the old managed recent/top/default flows at protocol/facade level through existing `messages.getRecentReactions`, `messages.getTopReactions`, `messages.setDefaultReaction`, `messages.clearRecentReactions`, and default reaction read from `help.getConfig` `Config.reactionsDefault`; UI remains mock-driven.
- Server-backed chat folders now use native MTProto `messages.getDialogFilters`, `messages.updateDialogFilter`, `messages.updateDialogFiltersOrder`, and `messages.toggleDialogFilterTags` through the existing transport facade. The Chats tab appends custom folder tabs from the server, applies old iOS-style include/exclude/pinned/category matching using parsed dialog peer metadata, and includes native folder management for create, edit, delete, drag reorder, and tag-display toggling. Shared folder invite links and joined-folder maintenance are protocol/facade-ready through existing server `chatlists.exportChatlistInvite`, `chatlists.getExportedInvites`, `chatlists.editExportedInvite`, `chatlists.deleteExportedInvite`, `chatlists.checkChatlistInvite`, `chatlists.joinChatlistInvite`, `chatlists.getChatlistUpdates`, `chatlists.joinChatlistUpdates`, `chatlists.hideChatlistUpdates`, `chatlists.getLeaveChatlistSuggestions`, and `chatlists.leaveChatlist`; UI remains mock-driven.
- Attachment menu options now mirror the old `AttachmentButtonType` surface for gallery, file, location, contact, poll, todo, and quick reply.
- Poll and todo message protocols are native facade-ready against the existing server MTProto methods: `messages.sendMedia(inputMediaPoll)`, `messages.sendMedia(inputMediaTodo)`, `messages.sendVote`, `messages.getPollResults`, `messages.getPollVotes`, `messages.toggleTodoCompleted`, and `messages.appendTodoList`. UI remains mock-driven while the UI branch owns this surface.
- Remaining parity: durable local update application, socket/background update streaming, albums/pasteboard/editor tools, thumbnail-backed shared-media cells, share/action-sheet polish, tag-color visual polish, and final folder UI parity styling. Historical server-returned `messageMediaWebPage` previews now parse/render in chat bubbles/shared-link rows, composer-side live previews use existing `messages.getWebPagePreview` with `no_webpage` dismissal on send/draft, and shared media browsing now exposes media/files/links/GIF/voice/music filters through existing `messages.search`, tab counters from old-iOS `messages.getSearchCounters`, and old calendar/position protocol facades through `messages.getSearchResultsCalendar` / `messages.getSearchResultsPositions`.
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
- Supergroup creation, detail edit, member list, server-backed member filters/search for recent/admins/contacts/bots/restricted/banned, local member search by name/username/role, shared contact invite picker, remove member, delete member history, configurable admin rights editor, configurable member restrictions with media sub-permissions/duration, group settings editor for slow mode/join-to-send/join requests/pre-history/member list visibility/anti-spam protection, anti-spam false-positive reporting through existing `channels.reportAntiSpamFalsePositive`, public username check/update service actions, configurable invite link create/list/edit/delete, invite importer/join-request listing, join-request approve/decline and approve-all/decline-all service actions, admin log, message pins, message-content read service actions through existing `channels.readMessageContents`, mark-read through existing `channels.readHistory`, clear-history through existing `channels.deleteHistory`, and message deletion through existing `channels.deleteMessages` exist.
- Remaining parity: rules acknowledgement, transliterated member search, default group-permission editor polish, and UI polish for dedicated banned/restricted list surfaces.

## 5. Channels Module

Native boundary:

- `HSgramNative/Channels/ChannelsView.swift`
- `HSgramNative/Channels/ChannelManageView.swift`
- Future split: channel visibility/public link controls, discussion group UI polish, post discussion/comment UI wiring, posting controls, subscriber/admin edge cases, and stats.

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
- Channel list/create/open chat, create-time contact subscriber selection, detail edit including current linked discussion group parsing from `channels.getFullChannel`, subscriber list, server-backed subscriber/admin/bot/restricted/banned filters, local subscriber search by name/username/role, contact invites, subscriber removal, configurable admin rights editor, public username check/update service actions, discussion-group candidate listing plus set/unlink service actions, channel post discussion snapshot/read service actions through existing `messages.getDiscussionMessage` / `messages.readDiscussion`, channel post view/forward/reply counter refresh through old-iOS `messages.getMessagesViews`, channel/group message read participant snapshots through old-iOS `messages.getMessageReadParticipants#31c1c44f`, channel/group reaction detail lists through old-iOS/server `messages.getMessageReactionsList#461b3f48`, channel message content-read service actions through existing `channels.readMessageContents`, channel mark-read through existing `channels.readHistory`, channel clear-history through existing `channels.deleteHistory`, channel message deletion through existing `channels.deleteMessages`, channel message signature read/write through current server-compatible `channels.toggleSignatures`, signature profile state parsing from channel flags, anti-spam protection read/write plus false-positive reporting through existing `channels.toggleAntiSpam` / `channels.reportAntiSpamFalsePositive`, configurable invite link create/list/edit/delete, invite importer/join-request listing, join-request approve/decline and approve-all/decline-all service actions, and admin log exist.
- Remaining parity: UI wiring for public/private visibility controls, UI polish for discussion group linkage, post discussion/comment UI wiring after the mock UI lands, signature profile write support after server compatibility approval, transliterated subscriber/admin search, subscriber/admin edge cases, channel stats if product keeps them.

## 6. Contacts Module

Native boundary:

- `HSgramNative/Contacts/ContactsView.swift`
- `HSgramNative/Contacts/AddContactSheet.swift`
- `HSgramNative/Contacts/ContactProfileView.swift`
- `HSgramNative/Contacts/ContactRow.swift`
- `HSgramNative/Contacts/ContactInvitePickerSheet.swift`
- Future split: invite contacts, avatar gallery, report actions, and richer device-contact sections.

Old source references:

- `submodules/ContactListUI`
- `submodules/ContactsHelper`
- `submodules/PeerInfoUI/Sources/UserInfoController.swift`
- `submodules/PeerInfoUI/Sources/DeviceContactInfoController.swift`
- `submodules/PeerInfoUI/Sources/PeerAvatarGalleryUI`

Native status:

- Contacts module boundary is in place for the contacts list, add/search/request sheet, profile actions, reusable contact row, and shared contact invite picker.
- Contacts list, user search, profile view, message entry, request, accept, decline, delete, block, unblock, device address-book import via existing `contacts.importContacts`, imported-phone cleanup via existing `contacts.deleteByPhones`, contact notes via existing `contacts.addContact` / `contacts.updateContactNote`, add-phone privacy exceptions via existing `contacts.addContact` flags, contact share-link export/import via existing `contacts.exportContactToken` / `contacts.importContactToken`, and native report adapters via existing `account.reportPeer`, `account.reportProfilePhoto`, and `messages.report` exist.
- Remaining parity: avatar viewing/update, report UI wiring, richer profile sections.

## 7. Media and Stickers Module

Native boundary:

- `HSgramNative/Chats/ChatAttachmentSheet.swift`
- `HSgramNative/Chats/MessageBubbleView.swift`
- `HSgramNative/Networking/HSAPIClient.swift`
- `HSgramNative/Networking/HSNativeMTProto.swift`
- Future split: sticker pack browser, custom emoji renderer, reaction picker UI, media editor, and pasteboard/album tools.

Old source references:

- `submodules/FeaturedStickersScreen`
- `submodules/StickerPackPreviewUI`
- `submodules/TelegramUI/Components/Chat/ChatControllerNode.swift`
- `submodules/TelegramUI/Components/Chat/ReactionSelectionNode`
- `submodules/TelegramCore/Sources/State/ManagedRecentStickers.swift`
- `submodules/TelegramCore/Sources/State/ManagedSynchronizeSavedGifsOperations.swift`
- `submodules/TelegramCore/Sources/State/MessageReactions.swift`

Native status:

- Media send, receive, download, preview, local cache, auto-download controls, shared-media search, counters, and old calendar/position service facades are covered through the private-chat service layer and existing MTProto media/search methods.
- Sticker pack catalog identities now retain old-iOS `StickerSet.accessHash`, and the service layer can install/uninstall packs plus mark featured sticker sets as read through existing server MTProto (`messages.installStickerSet`, `messages.uninstallStickerSet`, `messages.readFeaturedStickers`); UI remains mock-driven until the UI branch is ready.
- Sticker pack detail is protocol/facade-ready through existing server MTProto `messages.getStickerSet`, including id/access-hash and short-name inputs, packs, keywords, and sticker documents for old-iOS `StickerPackPreview` parity.
- Emoji sticker suggestions are protocol/facade-ready through existing server MTProto `messages.getStickers`, preserving hash/not-modified handling and sticker document metadata for old-iOS composer search parity.
- Custom emoji document resolution is protocol/facade-ready through existing server MTProto `messages.getCustomEmojiDocuments`, reusing the native sticker document parser for old-iOS `FetchedMediaResource` and animated emoji lookup parity.
- Custom emoji set listing and search are protocol/facade-ready through existing server MTProto `messages.getEmojiStickers` and `messages.searchCustomEmoji`, preserving hash/not-modified handling and document ids for later custom emoji renderer wiring.
- Emoji keyword full sync, difference sync, and supported-language lookup are protocol/facade-ready through existing server MTProto `messages.getEmojiKeywords`, `messages.getEmojiKeywordsDifference`, and `messages.getEmojiKeywordsLanguages`, matching the old managed emoji-keyword refresh path while the UI remains mock-driven.
- Saved GIF cloud state is protocol/facade-ready through existing server MTProto `messages.getSavedGifs` and `messages.saveGif`, matching the old `ManagedSynchronizeSavedGifsOperations` add/remove/sync path and preserving document id/access hash/file reference for later GIF keyboard wiring.
- Archived sticker pack listing is protocol/facade-ready through existing server MTProto `messages.getArchivedStickers`, including the old iOS namespace flags for stickers, masks, and emoji packs plus offset/limit paging.
- Recent sticker service state is protocol/facade-ready through existing server MTProto (`messages.getRecentStickers`, `messages.saveRecentSticker`, `messages.clearRecentStickers`) with sticker document ids, access hashes, file references, alt text, dimensions, and server dates preserved; `messages.getFavedStickers` is read and parsed, but current server core returns an empty faved list and does not expose a `messages.faveSticker` app handler yet.
- Reaction picker service state is protocol/facade-ready through existing server MTProto: available reactions from `messages.getAvailableReactions`, recent reactions from `messages.getRecentReactions`, top reactions from `messages.getTopReactions`, default reaction read from `help.getConfig` `Config.reactionsDefault`, default reaction write through `messages.setDefaultReaction`, and recent clearing through `messages.clearRecentReactions`.
- Remaining parity: faved sticker write once the server exposes it, custom emoji renderer/UI wiring after the mock UI branch lands, saved GIF keyboard UI wiring, reaction picker UI wiring, albums, pasteboard, and drawing/editor tools.
