# HSgram iOS Native Migration Plan

## Non-negotiables

- New iOS code must remain independent from the Telegram-iOS source tree.
- Bundle identifier remains `com.hsgram.app` unless App Store Connect strategy changes deliberately.
- Registration and sign-in are email-only in the iOS UI.
- Android and PC must continue to see the same users, dialogs, messages, contacts, circle state, moderation events, and trust/report state.
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
| Account | GET/PATCH | `/v1/account/profile` | Read and update display name, username, and bio. |
| Settings | GET | `/v1/settings/privacy` | Read privacy rule summaries from existing account privacy settings. |
| Settings | GET/PATCH | `/v1/settings/notifications` | Read and update private chat, group, and channel notification scopes. |
| Settings | GET | `/v1/settings/storage` | Read storage and asset summary for the settings screen. |
| Workspace | GET | `/workspace/summary` | Existing summary for Today metrics/actions. |
| Dialogs | GET | `/v1/dialogs` | List private chats, groups, and circles. |
| Messages | GET | `/v1/dialogs/{dialog_id}/messages` | Fetch recent messages for a dialog. |
| Messages | POST | `/v1/dialogs/{dialog_id}/messages` | Send a text message into the shared message pipeline. |
| Circles | GET | `/v1/circles` | List joined/admin circles and moderation counts. |
| Channels | GET/POST | `/v1/channels` | List broadcast channels and create new broadcast channels. |
| Channels | GET/PATCH | `/v1/channels/{dialog_id}` | Read or update channel title/about details. |
| Channels | GET | `/v1/channels/{dialog_id}/subscribers` | List channel subscribers/admin-visible participants. |
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
| Contacts | GET | `/v1/contacts` | List contacts and pending contact requests. |
| Trust | GET | `/v1/trust/items` | List trust events, reports, devices, and safety actions. |
| Devices | GET/DELETE | `/v1/devices`, `/v1/devices/{authorization_id}` | List active sessions and remotely log out non-current devices. |
| Premium + Enterprise | GET | `/v1/entitlements` | Return merged feature entitlement state for formerly premium and enterprise capabilities. |
| Admin Tools | GET | `/v1/admin/tools` | Return group/circle automation, moderation, reports, and operational tools available to the user. |

## Server Rule

The bridge cannot create a parallel chat store. Message sends must end in the same `msg` / sync path used by Android and PC, so cross-platform clients receive normal updates.

## Full Migration Scope

The rebuilt app must cover:

- Account: email sign-in/register, logout, sessions/devices, delete account, username/profile, privacy and security.
- Messaging: dialog list, private chats, groups/circles, message history, text/media messages, replies, forwards, edits, deletes, pins, unread/read state, search, mentions, reactions, drafts, saved messages.
- Media: photo/video picker, camera, documents, voice messages, link previews, downloads, storage settings, shared media browser.
- Contacts: contacts list, contact requests, invite flows, block/unblock, profile view.
- Circles and groups: creation, member list, admins, permissions, invite links, join requests, rules, recent actions, auto messages. Every newly created group in the native iOS app is a supergroup.
- Trust and moderation: report flows, spam/safety review, trust events, support, privacy checks.
- Merged premium + enterprise: advanced moderation/automation, premium assets/features currently present in backend, business/admin tools, without splitting product tiers in the iOS UX.
- Notifications: APNS registration, mute settings, badge/unread behavior, foreground/background update handling.
- Settings: appearance, language, data/storage, privacy, notifications, devices, help/support.
- App Store hardening: no Telegram-derived binary modules/assets/strings in the rebuilt target, complete privacy manifest, review account path through email only.

Deferred from the first rebuilt submission:

- 1:1 voice calls.
- Group voice/video chat.
- Live streaming.

## Phases

1. Native app shell: buildable Xcode project, email-only auth UI, HSgram tab structure.
2. Bridge MVP: implement email auth, dialogs, messages, workspace summary using existing BFF/DAO paths.
3. Full migration matrix: implement every non-deferred screen/action/API from the old iOS client, merging premium and enterprise features into the default HSgram surface.
4. Interop verification: send iOS -> Android, Android -> iOS, iOS -> PC, PC -> iOS; verify read/unread, group/circle membership, contact requests, reporting, admin tools, merged entitlements, and account deletion.
5. App Store hardening: icons/screenshots/metadata, privacy manifest, no Telegram binary strings/assets/modules.
