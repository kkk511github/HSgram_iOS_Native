# HSgram Native iOS Full Migration Matrix

This file is the checklist for replacing the rejected iOS codebase with a native HSgram app. A feature is not considered migrated until the iOS UI, native API contract, backend mapping, and Android/PC interoperability path are all covered.

## Status Legend

- Done: implemented and build-verified in the native project.
- Bridge: native UI exists and server facade is being mapped to existing backend services.
- Planned: required for 1:1 parity, not yet implemented.
- Deferred: intentionally out of first rebuilt submission.

## Matrix

| Area | Required Scope | Backend Rule | Status |
| --- | --- | --- | --- |
| Account and auth | Email-only sign-in/register, logout, sessions/devices, account deletion, profile, username | Use existing user/authsession/login-email state | Bridge with UI/API for email auth, logout, profile, username, and non-current device reset; planned for account deletion UI |
| Today workspace | Action Inbox, counts, review items, quick actions | Use existing workspace summary and trust/contact/circle tables | Bridge |
| Dialogs | Private chats, groups, circles, saved messages, unread state, pinned/archived state | Use existing dialog BFF/service state | Bridge with UI for dialog list, contact-to-private-chat, and circle-to-group-chat; planned for pinned/archived UI |
| Message history | Text history, service messages, read state, pagination | Use existing messages BFF and message store | Bridge with UI for history/read refresh, planned for pagination UI |
| Sending | Text, media, documents, voice, replies, forwards, edits, deletes, pins, drafts | Send through existing `messages.*` / `msg` / sync path | Bridge with UI for text/forward/edit/delete/reactions/pins/message links, planned for media/drafts |
| Media | Photo/video picker, camera, documents, downloads, shared media browser, storage controls | Use existing media/dfs services and shared media indexes | Planned |
| Stickers and emoji | Sticker packs, custom emoji, reactions, recent/favorites | Use existing sticker/emoji/reaction BFF paths | Last phase; bridge exists for catalog/reactions only |
| Contacts | Contacts list, requests, import/invite, block/unblock, user profile | Use existing contacts/user/privacy services | Bridge for list, planned for actions |
| Circles and groups | Create/manage circles as supergroups, member list, admins, permissions, invite links, join requests, rules | Use existing channel/supergroup chat state; new groups use `channels.createChannel` with `megagroup=true` | Bridge with UI for create/detail/members/remove/admin rights/member restrictions/settings/invite links/admin logs; planned for join-request/rules UIs |
| Circle tools | Auto messages, recent actions, rule acknowledgements, operational tools | Use existing auto-message and workspace tables | Bridge for tool catalog, planned for action UIs |
| Trust center | Reports, safety review, device/session review, support, privacy checks | Use existing report/authsession/privacy state | Bridge |
| Settings | Appearance, language, privacy/security, notifications, data/storage, help/support | Use existing account/configuration/notification services | Bridge with UI/API for profile, privacy summary, notification scopes, data/storage summary, devices; planned for appearance/language/support actions |
| Notifications | APNS token registration, badges, mute settings, foreground/background updates | Use existing notification service and sync updates | Bridge for mute/settings scopes; planned for APNS token/badges/background handling |
| Search | Chats, messages, contacts, media | Use existing search/global search services | Planned |
| Channels | Broadcast channel list, creation, posting, subscribers, invite links, admin log | Use existing channel state with `channels.createChannel` using `broadcast=true` | Bridge with UI for list/create/open channel chat; planned for subscriber/admin management UI |
| Premium + enterprise merge | Premium assets, admin/business/automation tools, advanced moderation, merged entitlements | Expose one HSgram entitlement surface; no split builds | Bridge |
| App Store hardening | Native bundle, privacy manifest, app icons/screenshots, review account, no Telegram-derived target code/assets | Keep rejected source tree out of app target | Planned |
| Voice calls | 1:1 voice calls | Keep future compatibility with call services | Deferred |
| Live/group calls | Group voice/video chat and live streaming | Keep future compatibility with call/live services | Deferred |

## First Verification Gate

The first useful end-to-end gate is:

1. Register a new account with email on native iOS.
2. See the same account on server auth/user tables.
3. Send iOS -> Android, Android -> iOS, iOS -> PC, PC -> iOS text messages.
4. Verify read/unread state and workspace counts do not diverge.
5. Confirm no mock session or fallback mock chat data is present in the iOS binary path.

## Native Bridge Added

- `GET /v1/account/profile`
- `PATCH /v1/account/profile`
- `GET /v1/settings/privacy`
- `GET /v1/settings/notifications`
- `PATCH /v1/settings/notifications`
- `GET /v1/settings/storage`
- `DELETE /v1/devices/{authorization_id}`
- `POST /v1/dialogs/{dialog_id}/read`
- `PATCH /v1/dialogs/{dialog_id}/messages/{message_id}`
- `DELETE /v1/dialogs/{dialog_id}/messages/{message_id}`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/forward`
- `POST /v1/dialogs/{dialog_id}/messages/{message_id}/reactions`

## Native Supergroup Bridge Added

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

## Native Channel Bridge Added

- `GET /v1/channels`
- `POST /v1/channels`
- `GET /v1/channels/{dialog_id}`
- `PATCH /v1/channels/{dialog_id}`
- `POST /v1/channels/{dialog_id}/leave`
- `GET /v1/channels/{dialog_id}/subscribers`
- `GET /v1/channels/{dialog_id}/admin-log`
- `POST /v1/channels/{dialog_id}/invites`
