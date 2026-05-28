import SwiftUI
import UIKit

struct ChatListView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var chats: [HSChat] = []
    @State private var archivedChats: [HSChat] = []
    @State private var draftsByDialogID: [Int64: HSDraft] = [:]
    @State private var dialogFiltersState = HSChatListFiltersState(tagsEnabled: false, filters: [])
    @State private var errorMessage: String?
    @State private var isShowingNewGroup = false
    @State private var isShowingAddContact = false
    @State private var isShowingPinnedOrder = false
    @State private var isShowingFolderManagement = false
    @State private var selectedFilter: ChatListFilterScope = .all

    private var savedMessagesChat: HSChat? {
        guard let session = authStore.session else {
            return nil
        }
        return HSChat(
            id: session.userID,
            title: "Saved Messages",
            subtitle: "Notes and forwarded messages",
            unreadCount: 0,
            isMarkedUnread: false,
            isCircle: false,
            updatedAt: nil
        )
    }

    private var activeChats: [HSChat] {
        chats.filter { !$0.isArchived }
    }

    private var customDialogFilters: [HSChatListFilter] {
        dialogFiltersState.filters.filter { !$0.isDefault }
    }

    private func orderedChats(_ items: [HSChat]) -> [HSChat] {
        items.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isPinned != rhs.element.isPinned {
                    return lhs.element.isPinned && !rhs.element.isPinned
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func replacingIfPresent(_ chat: HSChat, in items: [HSChat]) -> [HSChat] {
        orderedChats(items.map { $0.id == chat.id ? chat : $0 })
    }

    private var pinnedOrderFolderID: Int {
        selectedFilter == .archived ? HSChat.archiveFolderID : 0
    }

    private var pinnedOrderChats: [HSChat] {
        let source = selectedFilter == .archived ? archivedChats : activeChats
        return source.filter { $0.isPinned && !isSavedMessages($0) }
    }

    private func applyingPinnedOrder(_ orderedIDs: [Int64], to items: [HSChat]) -> [HSChat] {
        let chatsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let orderedIDSet = Set(orderedIDs)
        let reorderedPinned = orderedIDs.compactMap { chatsByID[$0] }
        let remainingPinned = items.filter { $0.isPinned && !orderedIDSet.contains($0.id) }
        let unpinned = items.filter { !$0.isPinned }
        return reorderedPinned + remainingPinned + unpinned
    }

    private var allDisplayedChats: [HSChat] {
        guard let savedMessagesChat else {
            return activeChats
        }
        var result = [savedMessagesChat]
        result.append(contentsOf: activeChats.filter { $0.id != savedMessagesChat.id })
        return result
    }

    private var allKnownChats: [HSChat] {
        var result = allDisplayedChats
        let knownIDs = Set(result.map(\.id))
        result.append(contentsOf: archivedChats.filter { !knownIDs.contains($0.id) })
        return result
    }

    private var displayedChats: [HSChat] {
        switch selectedFilter {
        case .archived:
            return archivedChats
        case .custom(let id):
            guard let filter = customDialogFilters.first(where: { $0.id == id }) else {
                return allDisplayedChats
            }
            return orderedCustomFilterChats(
                allKnownChats.filter { matches($0, filter: filter) },
                filter: filter
            )
        default:
            return allDisplayedChats.filter { chat in
                matchesSystemFilter(chat)
            }
        }
    }

    private func matchesSystemFilter(_ chat: HSChat) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .unread:
            return hasUnreadActivity(chat)
        case .contacts:
            return !isSavedMessages(chat) && !chat.isCircle
        case .groups:
            return chat.isCircle
        case .archived:
            return false
        case .custom:
            return true
        }
    }

    private func matches(_ chat: HSChat, filter: HSChatListFilter) -> Bool {
        if filter.isDefault {
            return !chat.isArchived
        }
        if filter.excludeArchived && chat.isArchived {
            return false
        }
        if filter.excludeMuted && chat.isMuted {
            return false
        }
        let excludedIDs = Set(filter.excludePeers.map(\.dialogID))
        if excludedIDs.contains(chat.id) {
            return false
        }
        if filter.excludeRead && !hasUnreadActivity(chat) {
            return false
        }

        let explicitIDs = Set((filter.includePeers + filter.pinnedPeers).map(\.dialogID))
        if explicitIDs.contains(chat.id) {
            return true
        }

        guard !filter.categories.isEmpty else {
            return false
        }
        return matches(chat, categories: filter.categories)
    }

    private func matches(_ chat: HSChat, categories: HSChatListFilterPeerCategories) -> Bool {
        if isSavedMessages(chat) {
            return false
        }
        if categories.contains(.bots), chat.peerKind == .user, chat.isBot {
            return true
        }
        if categories.contains(.contacts), chat.peerKind == .user, chat.isContact, !chat.isBot {
            return true
        }
        if categories.contains(.nonContacts), chat.peerKind == .user, !chat.isContact, !chat.isBot {
            return true
        }
        if categories.contains(.groups),
           chat.peerKind == .chat || (chat.peerKind == .channel && !chat.isBroadcast) {
            return true
        }
        if categories.contains(.channels), chat.peerKind == .channel, chat.isBroadcast {
            return true
        }
        return false
    }

    private func orderedCustomFilterChats(_ items: [HSChat], filter: HSChatListFilter) -> [HSChat] {
        let chatsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let pinnedIDs = filter.pinnedPeers.map(\.dialogID)
        let pinnedSet = Set(pinnedIDs)
        let pinned = pinnedIDs.compactMap { chatsByID[$0] }
        return pinned + items.filter { !pinnedSet.contains($0.id) }
    }

    private var filterCounts: ChatListFilterCounts {
        let customCounts = Dictionary(uniqueKeysWithValues: customDialogFilters.map { filter in
            (filter.id, allKnownChats.filter { matches($0, filter: filter) }.count)
        })
        return ChatListFilterCounts(
            all: allDisplayedChats.count,
            unread: allDisplayedChats.filter(hasUnreadActivity).count,
            contacts: allDisplayedChats.filter { !isSavedMessages($0) && !$0.isCircle }.count,
            groups: allDisplayedChats.filter(\.isCircle).count,
            archived: archivedChats.count,
            custom: customCounts
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let errorMessage {
                        HSErrorBanner(message: errorMessage)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }

                    ForEach(displayedChats) { chat in
                        NavigationLink {
                            ChatThreadView(chat: chat, mode: isSavedMessages(chat) ? .savedMessages : .automatic)
                        } label: {
                            ChatListRow(
                                chat: chat,
                                subtitle: subtitleText(for: chat),
                                subtitlePrefix: subtitlePrefix(for: chat),
                                dateText: dateText(for: chat),
                                icon: iconName(for: chat),
                                tint: iconColor(for: chat),
                                isSavedMessages: isSavedMessages(chat)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !isSavedMessages(chat) {
                                if chat.isPinned {
                                    Button {
                                        Task {
                                            await setPinned(chat, pinned: false)
                                        }
                                    } label: {
                                        Label("取消置顶", systemImage: "pin.slash")
                                    }
                                } else {
                                    Button {
                                        Task {
                                            await setPinned(chat, pinned: true)
                                        }
                                    } label: {
                                        Label("置顶", systemImage: "pin.fill")
                                    }
                                }

                                if chat.isArchived || selectedFilter == .archived {
                                    Button {
                                        Task {
                                            await setArchived(chat, archived: false)
                                        }
                                    } label: {
                                        Label("取消归档", systemImage: "archivebox.fill")
                                    }
                                } else {
                                    Button {
                                        Task {
                                            await setArchived(chat, archived: true)
                                        }
                                    } label: {
                                        Label("归档", systemImage: "archivebox")
                                    }
                                }
                            }

                            if hasUnreadActivity(chat) {
                                Button {
                                    Task {
                                        await markRead(chat)
                                    }
                                } label: {
                                    Label("标为已读", systemImage: "envelope.open")
                                }
                            } else {
                                Button {
                                    Task {
                                        await markUnread(chat)
                                    }
                                } label: {
                                    Label("标为未读", systemImage: "envelope.badge")
                                }
                            }
                        }
                    }
                }
            }
            .background(HSTheme.Chat.listBackground)
            .safeAreaInset(edge: .top, spacing: 0) {
                ChatListFilterBar(selection: $selectedFilter, counts: filterCounts, filters: customDialogFilters)
            }
            .overlay {
                if displayedChats.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 38, weight: .regular))
                            .foregroundStyle(HSTheme.secondaryText)
                        Text(errorMessage ?? emptyMessage)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(errorMessage == nil ? HSTheme.secondaryText : HSTheme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("聊天")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("搜索")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isShowingAddContact = true
                        } label: {
                            Label("添加联系人", systemImage: "person.badge.plus")
                        }

                        Button {
                            isShowingNewGroup = true
                        } label: {
                            Label("新建群组", systemImage: "person.3")
                        }

                        NavigationLink {
                            ChannelsView()
                        } label: {
                            Label("频道", systemImage: "megaphone")
                        }

                        Button {
                            isShowingPinnedOrder = true
                        } label: {
                            Label("管理置顶", systemImage: "pin")
                        }
                        .disabled(pinnedOrderChats.count < 2)

                        Button {
                            isShowingFolderManagement = true
                        } label: {
                            Label("管理文件夹", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建")
                }
            }
            .sheet(isPresented: $isShowingNewGroup) {
                NewSupergroupSheet { group in
                    let chat = HSChat(
                        id: group.id,
                        title: group.title,
                        subtitle: group.about.isEmpty ? "\(group.memberCount) members" : group.about,
                        unreadCount: 0,
                        isMarkedUnread: false,
                        isCircle: true,
                        peerKind: .channel,
                        isBroadcast: false,
                        updatedAt: nil
                    )
                    chats.removeAll { $0.id == chat.id }
                    chats = orderedChats([chat] + chats)
                }
                .environmentObject(authStore)
            }
            .sheet(isPresented: $isShowingAddContact) {
                AddContactSheet { _ in }
                    .environmentObject(authStore)
            }
            .sheet(isPresented: $isShowingPinnedOrder) {
                PinnedDialogOrderSheet(chats: pinnedOrderChats, folderID: pinnedOrderFolderID) { orderedIDs, folderID in
                    await reorderPinnedDialogs(orderedIDs, folderID: folderID)
                }
            }
            .sheet(isPresented: $isShowingFolderManagement) {
                ChatListFolderManagementSheet(
                    filtersState: $dialogFiltersState,
                    selectedFilter: $selectedFilter,
                    availableChats: allKnownChats.filter { !isSavedMessages($0) }
                )
                .environmentObject(authStore)
            }
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsRemoteNotificationDidArrive)) { _ in
                Task {
                    await refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsRemoteNotificationDidOpen)) { _ in
                Task {
                    await refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsNativeSyncDidChange)) { _ in
                Task {
                    await refresh()
                }
            }
        }
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all:
            return "暂无会话"
        case .unread:
            return "没有未读会话"
        case .contacts:
            return "暂无联系人会话"
        case .groups:
            return "暂无群组会话"
        case .archived:
            return "暂无归档会话"
        case .custom(let id):
            let title = customDialogFilters.first { $0.id == id }?.displayTitle ?? "文件夹"
            return "\(title) 暂无会话"
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            async let loadedTask = authStore.api.dialogs(session: session)
            async let archivedTask = authStore.api.dialogs(folderID: HSChat.archiveFolderID, session: session)
            async let draftsTask = authStore.api.drafts(session: session)
            async let filtersTask = authStore.api.dialogFilters(session: session)

            let loaded = try await loadedTask
            let loadedArchived = try await archivedTask
            let drafts = (try? await draftsTask) ?? []
            let filters = (try? await filtersTask) ?? HSChatListFiltersState(tagsEnabled: false, filters: [])

            chats = orderedChats(loaded)
            archivedChats = orderedChats(loadedArchived.map { $0.withFolderID(HSChat.archiveFolderID) })
            draftsByDialogID = Dictionary(uniqueKeysWithValues: drafts.map { ($0.dialogID, $0) })
            dialogFiltersState = filters
            if case .custom(let id) = selectedFilter,
               !filters.filters.contains(where: { !$0.isDefault && $0.id == id }) {
                selectedFilter = .all
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func subtitlePrefix(for chat: HSChat) -> String? {
        guard let draft = draftsByDialogID[chat.id],
              !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "Draft: "
    }

    private func subtitleText(for chat: HSChat) -> String {
        if let draft = draftsByDialogID[chat.id], !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return draft.text
        }
        return chat.subtitle
    }

    private func dateText(for chat: HSChat) -> String {
        guard let date = chat.updatedAt else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

    private func markRead(_ chat: HSChat) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.markDialogRead(dialogID: chat.id, session: session)
            chats = chats.map { item in
                guard item.id == chat.id else {
                    return item
                }
                return HSChat(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    unreadCount: 0,
                    readInboxMaxID: item.readInboxMaxID,
                    readOutboxMaxID: item.readOutboxMaxID,
                    isMarkedUnread: false,
                    isPinned: item.isPinned,
                    folderID: item.folderID,
                    isCircle: item.isCircle,
                    peerKind: item.peerKind,
                    isBot: item.isBot,
                    isContact: item.isContact,
                    isBroadcast: item.isBroadcast,
                    isMuted: item.isMuted,
                    updatedAt: item.updatedAt
                )
            }
            archivedChats = archivedChats.map { item in
                guard item.id == chat.id else {
                    return item
                }
                return HSChat(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    unreadCount: 0,
                    readInboxMaxID: item.readInboxMaxID,
                    readOutboxMaxID: item.readOutboxMaxID,
                    isMarkedUnread: false,
                    isPinned: item.isPinned,
                    folderID: item.folderID,
                    isCircle: item.isCircle,
                    peerKind: item.peerKind,
                    isBot: item.isBot,
                    isContact: item.isContact,
                    isBroadcast: item.isBroadcast,
                    isMuted: item.isMuted,
                    updatedAt: item.updatedAt
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markUnread(_ chat: HSChat) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.markDialogUnread(dialogID: chat.id, unread: true, session: session)
            chats = chats.map { item in
                guard item.id == chat.id else {
                    return item
                }
                return HSChat(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    unreadCount: item.unreadCount,
                    readInboxMaxID: item.readInboxMaxID,
                    readOutboxMaxID: item.readOutboxMaxID,
                    isMarkedUnread: true,
                    isPinned: item.isPinned,
                    folderID: item.folderID,
                    isCircle: item.isCircle,
                    peerKind: item.peerKind,
                    isBot: item.isBot,
                    isContact: item.isContact,
                    isBroadcast: item.isBroadcast,
                    isMuted: item.isMuted,
                    updatedAt: item.updatedAt
                )
            }
            archivedChats = archivedChats.map { item in
                guard item.id == chat.id else {
                    return item
                }
                return HSChat(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle,
                    unreadCount: item.unreadCount,
                    readInboxMaxID: item.readInboxMaxID,
                    readOutboxMaxID: item.readOutboxMaxID,
                    isMarkedUnread: true,
                    isPinned: item.isPinned,
                    folderID: item.folderID,
                    isCircle: item.isCircle,
                    peerKind: item.peerKind,
                    isBot: item.isBot,
                    isContact: item.isContact,
                    isBroadcast: item.isBroadcast,
                    isMuted: item.isMuted,
                    updatedAt: item.updatedAt
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setArchived(_ chat: HSChat, archived: Bool) async {
        guard let session = authStore.session, !isSavedMessages(chat) else {
            return
        }
        do {
            let targetFolderID = archived ? HSChat.archiveFolderID : 0
            _ = try await authStore.api.setDialogFolder(dialogID: chat.id, folderID: targetFolderID, session: session)
            let updated = chat.withFolderID(archived ? HSChat.archiveFolderID : nil)
            chats.removeAll { $0.id == chat.id }
            archivedChats.removeAll { $0.id == chat.id }
            if archived {
                archivedChats = orderedChats([updated] + archivedChats)
            } else {
                chats = orderedChats([updated] + chats)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setPinned(_ chat: HSChat, pinned: Bool) async {
        guard let session = authStore.session, !isSavedMessages(chat) else {
            return
        }
        do {
            _ = try await authStore.api.setDialogPinned(dialogID: chat.id, pinned: pinned, session: session)
            let updated = chat.withPinned(pinned)
            chats = replacingIfPresent(updated, in: chats)
            archivedChats = replacingIfPresent(updated, in: archivedChats)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reorderPinnedDialogs(_ orderedIDs: [Int64], folderID: Int) async {
        guard let session = authStore.session, orderedIDs.count > 1 else {
            return
        }
        do {
            _ = try await authStore.api.reorderPinnedDialogs(dialogIDs: orderedIDs, folderID: folderID, session: session)
            if folderID == HSChat.archiveFolderID {
                archivedChats = applyingPinnedOrder(orderedIDs, to: archivedChats)
            } else {
                chats = applyingPinnedOrder(orderedIDs, to: chats)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hasUnreadActivity(_ chat: HSChat) -> Bool {
        chat.unreadCount > 0 || chat.isMarkedUnread
    }

    private func isSavedMessages(_ chat: HSChat) -> Bool {
        chat.id == savedMessagesChat?.id
    }

    private func iconName(for chat: HSChat) -> String {
        if isSavedMessages(chat) {
            return "bookmark.fill"
        }
        return chat.isCircle ? "person.3.fill" : "person.fill"
    }

    private func iconColor(for chat: HSChat) -> Color {
        if isSavedMessages(chat) {
            return HSTheme.trust
        }
        return chat.isCircle ? HSTheme.circle : HSTheme.accent
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PinnedDialogOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderedChats: [HSChat]
    @State private var isSaving = false

    let folderID: Int
    let onSave: ([Int64], Int) async -> Void

    init(chats: [HSChat], folderID: Int, onSave: @escaping ([Int64], Int) async -> Void) {
        self.folderID = folderID
        self.onSave = onSave
        _orderedChats = State(initialValue: chats)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedChats) { chat in
                    HStack(spacing: 12) {
                        HSClassicAvatar(title: chat.title, icon: chat.isCircle ? "person.3.fill" : "person.fill", tint: chat.isCircle ? HSTheme.circle : HSTheme.accent, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chat.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(HSTheme.primaryText)
                                .lineLimit(1)
                            Text(chat.subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(HSTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(height: 48)
                }
                .onMove { offsets, destination in
                    orderedChats.move(fromOffsets: offsets, toOffset: destination)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(folderID == HSChat.archiveFolderID ? "归档置顶" : "置顶会话")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中" : "完成") {
                        Task {
                            isSaving = true
                            await onSave(orderedChats.map(\.id), folderID)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving || orderedChats.count < 2)
                }
            }
        }
    }
}

struct ChatListFolderManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore
    @Binding var filtersState: HSChatListFiltersState
    @Binding var selectedFilter: ChatListFilterScope
    @State private var editorContext: ChatListFolderEditorContext?
    @State private var errorMessage: String?
    @State private var isUpdatingTags = false

    let availableChats: [HSChat]
    let wrapsInNavigationStack: Bool
    let showsCloseButton: Bool

    private var customFilters: [HSChatListFilter] {
        filtersState.filters.filter { !$0.isDefault }
    }

    init(
        filtersState: Binding<HSChatListFiltersState>,
        selectedFilter: Binding<ChatListFilterScope>,
        availableChats: [HSChat],
        wrapsInNavigationStack: Bool = true,
        showsCloseButton: Bool = true
    ) {
        self._filtersState = filtersState
        self._selectedFilter = selectedFilter
        self.availableChats = availableChats
        self.wrapsInNavigationStack = wrapsInNavigationStack
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack {
                    folderManagementContent
                }
            } else {
                folderManagementContent
            }
        }
    }

    private var folderManagementContent: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { filtersState.tagsEnabled },
                    set: { value in
                        Task {
                            await setTagsEnabled(value)
                        }
                    }
                )) {
                    Label("显示文件夹标签", systemImage: "tag")
                }
                .disabled(isUpdatingTags)
            }

            Section("文件夹") {
                if customFilters.isEmpty {
                    Text("暂无文件夹")
                        .foregroundStyle(HSTheme.secondaryText)
                }

                ForEach(customFilters) { filter in
                    Button {
                        if filter.isEditable {
                            editorContext = ChatListFolderEditorContext(filter: filter, isNew: false)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: filter.isShared ? "person.2.crop.square.stack" : "folder")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(HSTheme.accent)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    if let emoticon = filter.emoticon, !emoticon.isEmpty {
                                        Text(emoticon)
                                    }
                                    Text(filter.displayTitle)
                                        .foregroundStyle(HSTheme.primaryText)
                                }
                                HStack(spacing: 8) {
                                    Text("\(filter.includePeers.count) 包含")
                                    if !filter.excludePeers.isEmpty {
                                        Text("\(filter.excludePeers.count) 排除")
                                    }
                                    if filter.excludeRead {
                                        Text("未读")
                                    }
                                    if filter.excludeArchived {
                                        Text("非归档")
                                    }
                                }
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(HSTheme.secondaryText)
                            }

                            Spacer()

                            if filter.isShared {
                                Text("共享")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!filter.isEditable)
                }
                .onDelete(perform: deleteFilters)
                .onMove(perform: moveFilters)
            }
        }
        .navigationTitle("聊天文件夹")
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    editorContext = ChatListFolderEditorContext(filter: newFilter(), isNew: true)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建文件夹")
            }
        }
        .sheet(item: $editorContext) { context in
            ChatListFolderEditorSheet(filter: context.filter, isNew: context.isNew, availableChats: availableChats) { filter in
                try await saveFilter(filter)
            }
        }
    }

    private func newFilter() -> HSChatListFilter {
        HSChatListFilter(
            id: newFilterID(),
            title: "",
            emoticon: nil,
            color: nil,
            isDefault: false,
            isShared: false,
            hasSharedLinks: false,
            categories: [],
            excludeMuted: false,
            excludeRead: false,
            excludeArchived: true,
            includePeers: [],
            pinnedPeers: [],
            excludePeers: [],
            titleAnimationsEnabled: true
        )
    }

    private func newFilterID() -> Int {
        let existingIDs = Set(filtersState.filters.map(\.id))
        for _ in 0..<512 {
            let id = Int.random(in: 2..<255)
            if !existingIDs.contains(id) {
                return id
            }
        }
        return (2..<255).first { !existingIDs.contains($0) } ?? 254
    }

    private func setTagsEnabled(_ enabled: Bool) async {
        guard let session = authStore.session, !isUpdatingTags else {
            return
        }
        isUpdatingTags = true
        defer { isUpdatingTags = false }
        do {
            _ = try await authStore.api.setDialogFilterTagsEnabled(enabled, session: session)
            filtersState = HSChatListFiltersState(tagsEnabled: enabled, filters: filtersState.filters)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFilter(_ filter: HSChatListFilter) async throws {
        guard let session = authStore.session else {
            throw HSAPIError.server(code: "NO_SESSION", message: "请先登录。")
        }
        _ = try await authStore.api.updateDialogFilter(filter, session: session)
        var filters = filtersState.filters
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index] = filter
        } else {
            filters.append(filter)
        }
        filtersState = HSChatListFiltersState(tagsEnabled: filtersState.tagsEnabled, filters: filters)
        errorMessage = nil
    }

    private func deleteFilters(at offsets: IndexSet) {
        let targets = offsets.compactMap { index in
            customFilters.indices.contains(index) ? customFilters[index] : nil
        }.filter(\.isEditable)
        guard !targets.isEmpty else {
            return
        }
        Task {
            guard let session = authStore.session else {
                errorMessage = "请先登录。"
                return
            }
            do {
                for filter in targets {
                    _ = try await authStore.api.deleteDialogFilter(id: filter.id, session: session)
                }
                let deletedIDs = Set(targets.map(\.id))
                let filters = filtersState.filters.filter { !deletedIDs.contains($0.id) }
                filtersState = HSChatListFiltersState(tagsEnabled: filtersState.tagsEnabled, filters: filters)
                if case .custom(let id) = selectedFilter, deletedIDs.contains(id) {
                    selectedFilter = .all
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func moveFilters(from offsets: IndexSet, to destination: Int) {
        var custom = customFilters
        custom.move(fromOffsets: offsets, toOffset: destination)
        let customIDs = Set(custom.map(\.id))
        let defaults = filtersState.filters.filter { !customIDs.contains($0.id) && $0.isDefault }
        filtersState = HSChatListFiltersState(tagsEnabled: filtersState.tagsEnabled, filters: defaults + custom)

        Task {
            guard let session = authStore.session else {
                errorMessage = "请先登录。"
                return
            }
            do {
                _ = try await authStore.api.reorderDialogFilters(ids: custom.map(\.id), session: session)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ChatListFolderEditorContext: Identifiable {
    let filter: HSChatListFilter
    let isNew: Bool

    var id: String {
        "\(filter.id):\(isNew)"
    }
}

private struct ChatListFolderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var emoticon: String
    @State private var categories: HSChatListFilterPeerCategories
    @State private var excludeMuted: Bool
    @State private var excludeRead: Bool
    @State private var excludeArchived: Bool
    @State private var includePeers: [HSChatListFilterPeer]
    @State private var pinnedPeers: [HSChatListFilterPeer]
    @State private var excludePeers: [HSChatListFilterPeer]
    @State private var isSaving = false
    @State private var errorMessage: String?

    let filter: HSChatListFilter
    let isNew: Bool
    let availableChats: [HSChat]
    let onSave: (HSChatListFilter) async throws -> Void

    init(filter: HSChatListFilter, isNew: Bool, availableChats: [HSChat], onSave: @escaping (HSChatListFilter) async throws -> Void) {
        self.filter = filter
        self.isNew = isNew
        self.availableChats = availableChats
        self.onSave = onSave
        _title = State(initialValue: filter.title)
        _emoticon = State(initialValue: filter.emoticon ?? "")
        _categories = State(initialValue: filter.categories)
        _excludeMuted = State(initialValue: filter.excludeMuted)
        _excludeRead = State(initialValue: filter.excludeRead)
        _excludeArchived = State(initialValue: filter.excludeArchived)
        _includePeers = State(initialValue: filter.includePeers)
        _pinnedPeers = State(initialValue: filter.pinnedPeers)
        _excludePeers = State(initialValue: filter.excludePeers)
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                Section("名称") {
                    TextField("文件夹名称", text: $title)
                    TextField("图标", text: $emoticon)
                }

                Section("包含分类") {
                    categoryToggle("联系人", category: .contacts, systemImage: "person")
                    categoryToggle("非联系人", category: .nonContacts, systemImage: "person.crop.circle.badge.questionmark")
                    categoryToggle("群组", category: .groups, systemImage: "person.3")
                    categoryToggle("频道", category: .channels, systemImage: "megaphone")
                    categoryToggle("机器人", category: .bots, systemImage: "cpu")
                }

                Section("排除") {
                    Toggle(isOn: $excludeMuted) {
                        Label("静音会话", systemImage: "bell.slash")
                    }
                    Toggle(isOn: $excludeRead) {
                        Label("已读会话", systemImage: "envelope.open")
                    }
                    Toggle(isOn: $excludeArchived) {
                        Label("归档会话", systemImage: "archivebox")
                    }
                }

                Section("包含会话") {
                    peerToggleRows(mode: .include)
                }

                Section("置顶会话") {
                    peerToggleRows(mode: .pinned)
                }

                Section("排除会话") {
                    peerToggleRows(mode: .exclude)
                }
            }
            .navigationTitle(isNew ? "新建文件夹" : "编辑文件夹")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中" : "保存") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func categoryToggle(_ title: String, category: HSChatListFilterPeerCategories, systemImage: String) -> some View {
        Toggle(isOn: Binding(
            get: { categories.contains(category) },
            set: { enabled in
                if enabled {
                    categories.insert(category)
                } else {
                    categories.remove(category)
                }
            }
        )) {
            Label(title, systemImage: systemImage)
        }
    }

    @ViewBuilder
    private func peerToggleRows(mode: ChatListFolderPeerToggleMode) -> some View {
        let chats = mode == .pinned ? availableChats.filter { containsPeer($0.chatListFilterPeer, in: includePeers) } : availableChats
        if chats.isEmpty {
            Text("暂无会话")
                .foregroundStyle(HSTheme.secondaryText)
        }
        ForEach(chats) { chat in
            let peer = chat.chatListFilterPeer
            Toggle(isOn: Binding(
                get: { isSelected(peer, mode: mode) },
                set: { selected in
                    setSelected(selected, peer: peer, mode: mode)
                }
            )) {
                HStack(spacing: 10) {
                    HSClassicAvatar(title: chat.title, icon: chat.isCircle ? "person.3.fill" : "person.fill", tint: chat.isCircle ? HSTheme.circle : HSTheme.accent, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.title)
                            .foregroundStyle(HSTheme.primaryText)
                            .lineLimit(1)
                        Text(chat.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(HSTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func isSelected(_ peer: HSChatListFilterPeer, mode: ChatListFolderPeerToggleMode) -> Bool {
        switch mode {
        case .include:
            return containsPeer(peer, in: includePeers)
        case .pinned:
            return containsPeer(peer, in: pinnedPeers)
        case .exclude:
            return containsPeer(peer, in: excludePeers)
        }
    }

    private func setSelected(_ selected: Bool, peer: HSChatListFilterPeer, mode: ChatListFolderPeerToggleMode) {
        switch mode {
        case .include:
            if selected {
                addPeer(peer, to: &includePeers)
                removePeer(peer, from: &excludePeers)
            } else {
                removePeer(peer, from: &includePeers)
                removePeer(peer, from: &pinnedPeers)
            }
        case .pinned:
            if selected {
                addPeer(peer, to: &includePeers)
                addPeer(peer, to: &pinnedPeers)
                removePeer(peer, from: &excludePeers)
            } else {
                removePeer(peer, from: &pinnedPeers)
            }
        case .exclude:
            if selected {
                addPeer(peer, to: &excludePeers)
                removePeer(peer, from: &includePeers)
                removePeer(peer, from: &pinnedPeers)
            } else {
                removePeer(peer, from: &excludePeers)
            }
        }
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return
        }
        let trimmedEmoticon = emoticon.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = HSChatListFilter(
            id: filter.id,
            title: trimmedTitle,
            emoticon: trimmedEmoticon.isEmpty ? nil : trimmedEmoticon,
            color: filter.color,
            isDefault: false,
            isShared: filter.isShared,
            hasSharedLinks: filter.hasSharedLinks,
            categories: categories,
            excludeMuted: excludeMuted,
            excludeRead: excludeRead,
            excludeArchived: excludeArchived,
            includePeers: includePeers,
            pinnedPeers: pinnedPeers,
            excludePeers: excludePeers,
            titleAnimationsEnabled: filter.titleAnimationsEnabled
        )

        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(updated)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func containsPeer(_ peer: HSChatListFilterPeer, in peers: [HSChatListFilterPeer]) -> Bool {
        peers.contains { $0.dialogID == peer.dialogID }
    }

    private func addPeer(_ peer: HSChatListFilterPeer, to peers: inout [HSChatListFilterPeer]) {
        guard !containsPeer(peer, in: peers) else {
            return
        }
        peers.insert(peer, at: 0)
    }

    private func removePeer(_ peer: HSChatListFilterPeer, from peers: inout [HSChatListFilterPeer]) {
        peers.removeAll { $0.dialogID == peer.dialogID }
    }
}

private enum ChatListFolderPeerToggleMode {
    case include
    case pinned
    case exclude
}

private struct ChatListRow: View {
    let chat: HSChat
    let subtitle: String
    let subtitlePrefix: String?
    let dateText: String
    let icon: String
    let tint: Color
    let isSavedMessages: Bool

    var body: some View {
        HStack(spacing: 10) {
            HSClassicAvatar(title: chat.title, icon: icon, tint: tint, size: 60)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(chat.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(HSTheme.primaryText)
                            .lineLimit(1)

                        if chat.isMuted {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HSTheme.secondaryText)
                                .accessibilityLabel("Muted")
                        }
                    }

                    Spacer(minLength: 8)

                    if !dateText.isEmpty {
                        Text(dateText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HSTheme.Chat.dateText)
                            .lineLimit(1)
                    }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    Group {
                        if let subtitlePrefix {
                            Text(subtitlePrefix)
                                .foregroundColor(HSTheme.warning)
                                + Text(subtitle)
                        } else {
                            Text(subtitle)
                        }
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(1)
                    .frame(minHeight: 22, alignment: .topLeading)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        if chat.unreadCount > 0 {
                            HSClassicUnreadBadge(count: chat.unreadCount, muted: chat.isMuted)
                        } else if chat.isMarkedUnread {
                            Circle()
                                .fill(chat.isMuted ? HSTheme.Chat.mutedBadge : HSTheme.accent)
                                .frame(width: 10, height: 10)
                                .accessibilityLabel("Marked unread")
                        } else if chat.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(HSTheme.secondaryText)
                                .frame(width: 20, height: 20)
                                .accessibilityLabel("Pinned")
                        } else if isSavedMessages {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(HSTheme.disclosure)
                        }
                    }
                    .frame(minWidth: trailingAccessoryMinWidth, alignment: .trailing)
                }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .frame(height: 75)
        .background(chat.isPinned ? HSTheme.Chat.pinnedRowBackground : HSTheme.Chat.rowBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HSTheme.separator.opacity(0.75))
                .frame(height: 1 / UIScreen.main.scale)
                .padding(.leading, 80)
        }
        .contentShape(Rectangle())
    }

    private var trailingAccessoryMinWidth: CGFloat {
        chat.unreadCount > 99 ? 34 : 22
    }
}
