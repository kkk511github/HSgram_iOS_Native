import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVKit

enum HSChatThreadMode {
    case automatic
    case channel
    case savedMessages
}

private struct HSMediaPreviewItem: Identifiable {
    let id: Int64
    let url: URL
    let media: HSMessageMedia
    let image: UIImage?
}

private struct HSPendingAttachmentUpload: Identifiable {
    let id: UUID
    let localMessageID: Int64
    let data: Data
    let fileName: String
    let mimeType: String
    let mediaKind: String
    let duration: Double?
    let waveform: Data?
    let caption: String
    let replyToMessageID: Int64?
    let replyMessage: HSMessage?
}

private enum PrivateChatHistoryAction {
    case clearHistory
    case deleteChat
    case deleteForEveryone

    var title: String {
        switch self {
        case .clearHistory:
            return "Clear History"
        case .deleteChat:
            return "Delete Chat"
        case .deleteForEveryone:
            return "Delete for Both"
        }
    }

    var message: String {
        switch self {
        case .clearHistory:
            return "Remove the message history while keeping this chat in your list."
        case .deleteChat:
            return "Remove this chat and its history from your account."
        case .deleteForEveryone:
            return "Remove this private chat and its history for both sides."
        }
    }

    var justClear: Bool {
        self == .clearHistory
    }

    var revoke: Bool {
        self == .deleteForEveryone
    }

    var dismissesThread: Bool {
        self != .clearHistory
    }

    var successMessage: String {
        switch self {
        case .clearHistory:
            return "History cleared."
        case .deleteChat:
            return "Chat deleted."
        case .deleteForEveryone:
            return "Chat deleted for both sides."
        }
    }
}

struct ChatThreadView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    let chat: HSChat
    let mode: HSChatThreadMode

    @State private var messages: [HSMessage] = []
    @State private var draft = ""
    @State private var linkPreview: HSWebPagePreview?
    @State private var linkPreviewSourceURL: String?
    @State private var dismissedLinkPreviewURL: String?
    @State private var isLoadingLinkPreview = false
    @State private var linkPreviewTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var editingMessage: HSMessage?
    @State private var editText = ""
    @State private var forwardingMessage: HSMessage?
    @State private var replyingToMessage: HSMessage?
    @State private var draftReplyToMessageID: Int64?
    @State private var isLoadingOlder = false
    @State private var hasMoreHistory = true
    @State private var preserveMessageID: Int64?
    @State private var shouldScrollToLatest = true
    @State private var scrollTargetMessageID: Int64?
    @State private var highlightedSearchMessageID: Int64?
    @State private var isResolvingSearchResult = false
    @State private var isThreadSearchActive = false
    @State private var threadSearchQuery = ""
    @State private var threadSearchResults: [ChatSearchResult] = []
    @State private var currentThreadSearchIndex: Int?
    @State private var isThreadSearchSearching = false
    @State private var didPerformThreadSearch = false
    @State private var isShowingThreadSearchResults = false
    @State private var isShowingAttachmentSheet = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCameraCapture = false
    @State private var isShowingFileImporter = false
    @State private var pendingAttachmentUpload: HSPendingAttachmentUpload?
    @State private var attachmentUploadFailed = false
    @State private var attachmentUploadTask: Task<Void, Never>?
    @State private var selectedMessageIDs: Set<Int64> = []
    @State private var isShowingSelectionForwardSheet = false
    @State private var isShowingSelectionDeleteConfirmation = false
    @State private var mediaDownloadStates: [Int64: HSMediaDownloadState] = [:]
    @State private var mediaDownloadTasks: [Int64: Task<Void, Never>] = [:]
    @State private var downloadedMediaURLs: [Int64: URL] = [:]
    @State private var mediaPreviewItem: HSMediaPreviewItem?
    @State private var isShowingSharedMediaBrowser = false
    @State private var autoDownloadContactIDs: Set<Int64> = []
    @State private var didLoadAutoDownloadContacts = false
    @State private var unreadSeparatorMessageID: Int64?
    @State private var shouldScrollToUnreadSeparator = false
    @State private var didResolveInitialUnreadSeparator = false
    @State private var readOutboxMaxID: Int64
    @State private var pendingHistoryAction: PrivateChatHistoryAction?
    @State private var isPeerMuted: Bool
    @State private var isShowingCustomMuteDialog = false
    @State private var customMuteHoursText = "8"
    @State private var remoteInputActivity: HSInputActivity?
    @State private var lastSentInputActivity: (kind: HSInputActivityKind, date: Date)?
    @State private var inputActivityCleanupTask: Task<Void, Never>?

    private let pageSize = 50
    private let unreadSeparatorScrollID = "hs-unread-separator"
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let inputActivityThrottle: TimeInterval = 4
    private static let muteForeverInterval = Int(Int32.max)

    private var activeReplyToMessageID: Int64? {
        replyingToMessage?.id ?? draftReplyToMessageID
    }

    private var currentRemoteInputActivity: HSInputActivity? {
        guard let remoteInputActivity, remoteInputActivity.expiresAt > Date() else {
            return nil
        }
        return remoteInputActivity
    }

    private var isSavedMessagesMode: Bool {
        if case .savedMessages = mode {
            return true
        }
        return false
    }

    private var canManagePrivateChatHistory: Bool {
        chat.peerKind == .user && !chat.isCircle && !isSavedMessagesMode
    }

    private var messagesByID: [Int64: HSMessage] {
        Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
    }

    private var localOutgoingMessages: [HSMessage] {
        messages.filter { $0.id < 0 && $0.isOutgoing }
    }

    private var isSelectionMode: Bool {
        !selectedMessageIDs.isEmpty
    }

    private var selectedMessages: [HSMessage] {
        messages.filter { selectedMessageIDs.contains($0.id) }
    }

    private var selectedMessagesContainText: Bool {
        selectedMessages.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var messageRows: [ChatThreadMessageRow] {
        messages.indices.map { index in
            let message = messages[index]
            let previousMessage = index > messages.startIndex ? messages[messages.index(before: index)] : nil
            let nextMessage = index < messages.index(before: messages.endIndex) ? messages[messages.index(after: index)] : nil
            return ChatThreadMessageRow(
                message: message,
                previousMessage: previousMessage,
                isMergedWithPrevious: canMerge(message, withPrevious: previousMessage),
                isMergedWithNext: canMerge(message, withNext: nextMessage)
            )
        }
    }

    private var displaysPeerAuthors: Bool {
        chat.isCircle || chat.peerKind == .chat || (chat.peerKind == .channel && !chat.isBroadcast)
    }

    private func shouldShowAvatar(for message: HSMessage, row: ChatThreadMessageRow) -> Bool {
        displaysPeerAuthors && !message.isOutgoing && !row.isMergedWithNext
    }

    private func displayMessage(_ message: HSMessage) -> HSMessage {
        guard message.isOutgoing,
              message.deliveryState == .sent,
              readOutboxMaxID > 0,
              message.id <= readOutboxMaxID else {
            return message
        }
        return message.withDeliveryState(.read)
    }

    private var threadContact: HSContact {
        HSContact(
            id: chat.id,
            displayName: chat.title,
            username: usernameFromSubtitle,
            status: "contact"
        )
    }

    private var usernameFromSubtitle: String? {
        let trimmed = chat.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("@"), trimmed.count > 1 else {
            return nil
        }
        return String(trimmed.dropFirst())
    }

    init(chat: HSChat, mode: HSChatThreadMode = .automatic) {
        self.chat = chat
        self.mode = mode
        _readOutboxMaxID = State(initialValue: chat.readOutboxMaxID)
        _isPeerMuted = State(initialValue: chat.isMuted)
    }

    var body: some View {
        VStack(spacing: 0) {
            threadSearchInput
            messageTimeline
            bottomInteractionBar
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(HSChatWallpaper().ignoresSafeArea())
        .toolbar {
            threadToolbar
        }
        .alert("编辑消息", isPresented: Binding(
            get: { editingMessage != nil },
            set: { isPresented in
                if !isPresented {
                    editingMessage = nil
                    editText = ""
                }
            }
        )) {
            TextField("消息", text: $editText)
            Button("保存") {
                Task {
                    await saveEdit()
                }
            }
            Button("取消", role: .cancel) {
                editingMessage = nil
                editText = ""
            }
        }
        .sheet(item: $forwardingMessage) { message in
            ForwardDialogSheet(currentDialogID: chat.id) { target in
                Task {
                    await forward(message, to: target)
                }
            }
            .environmentObject(authStore)
        }
        .sheet(isPresented: $isShowingSelectionForwardSheet) {
            ForwardDialogSheet(currentDialogID: chat.id) { target in
                Task {
                    await forwardSelectedMessages(to: target)
                }
            }
            .environmentObject(authStore)
        }
        .sheet(isPresented: $isShowingAttachmentSheet) {
            ChatAttachmentSheet { option in
                handleAttachment(option)
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotoItem) { item in
            guard let item else {
                return
            }
            Task {
                await sendPhotoPickerItem(item)
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $isShowingCameraCapture) {
            HSCameraCaptureView { result in
                isShowingCameraCapture = false
                if let result {
                    sendCameraCaptureResult(result)
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await sendImportedFile(result)
            }
        }
        .sheet(isPresented: $isShowingThreadSearchResults) {
            ChatSearchResultsList(
                query: threadSearchQuery,
                results: threadSearchResults,
                currentMessageID: currentThreadSearchResult?.messageID
            ) { result in
                isShowingThreadSearchResults = false
                selectThreadSearchResult(result)
            }
        }
        .sheet(item: $mediaPreviewItem) { item in
            MediaPreviewSheet(item: item)
        }
        .sheet(isPresented: $isShowingSharedMediaBrowser) {
            SharedMediaBrowserView(chat: chat) { message in
                Task {
                    await openSharedMediaMessage(message)
                }
            }
            .environmentObject(authStore)
        }
        .task {
            await refresh()
            await loadDraft()
            scheduleLinkPreviewRefresh(for: draft)
        }
        .onChange(of: draft) { newValue in
            scheduleLinkPreviewRefresh(for: newValue)
            handleDraftInputActivity(newValue)
        }
        .onDisappear {
            inputActivityCleanupTask?.cancel()
            cancelActiveTransfersOnDisappear()
            linkPreviewTask?.cancel()
            Task {
                await sendInputActivity(.cancel, force: true)
                await saveDraft()
            }
        }
        .confirmationDialog(
            "删除选中的消息？",
            isPresented: $isShowingSelectionDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除 \(selectedMessageIDs.count) 条消息", role: .destructive) {
                Task {
                    await deleteSelectedMessages()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            pendingHistoryAction?.title ?? "Chat History",
            isPresented: Binding(
                get: { pendingHistoryAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingHistoryAction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingHistoryAction {
                Button(pendingHistoryAction.title, role: .destructive) {
                    let action = pendingHistoryAction
                    self.pendingHistoryAction = nil
                    Task {
                        await applyHistoryAction(action)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingHistoryAction = nil
            }
        } message: {
            if let pendingHistoryAction {
                Text(pendingHistoryAction.message)
            }
        }
        .alert("Custom Mute", isPresented: $isShowingCustomMuteDialog) {
            TextField("Hours", text: $customMuteHoursText)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
            Button("Mute") {
                applyCustomMuteHours()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the number of hours to mute this private chat.")
        }
    }

    @ToolbarContentBuilder
    private var threadToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ChatThreadNavigationTitle(chat: chat, mode: mode, inputActivity: currentRemoteInputActivity)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                isShowingSharedMediaBrowser = true
            } label: {
                Image(systemName: "rectangle.stack")
            }
            .disabled(isThreadSearchActive)
            Button {
                beginThreadSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(isThreadSearchActive)
            if case .channel = mode {
                NavigationLink {
                    ChannelManageView(chat: chat)
                } label: {
                    Image(systemName: "info.circle")
                }
            } else if chat.isCircle {
                NavigationLink {
                    SupergroupManageView(chat: chat)
                } label: {
                    Image(systemName: "info.circle")
                }
            } else if !isSavedMessagesMode {
                NavigationLink {
                    ContactProfileView(contact: threadContact)
                } label: {
                    Image(systemName: "info.circle")
                }
            }
            if canManagePrivateChatHistory {
                Menu {
                    privateChatOptionsMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isThreadSearchActive)
            }
            Button {
                Task {
                    await refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private var privateChatOptionsMenu: some View {
        Button {
            Task {
                await updatePeerMute(interval: 0)
            }
        } label: {
            Label(isPeerMuted ? "Enable Notifications" : "Notifications On", systemImage: "bell")
        }
        .disabled(!isPeerMuted)

        Button {
            Task {
                await updatePeerMute(interval: 60 * 60)
            }
        } label: {
            Label("Mute for 1 Hour", systemImage: "bell.slash")
        }

        Button {
            Task {
                await updatePeerMute(interval: 2 * 24 * 60 * 60)
            }
        } label: {
            Label("Mute for 2 Days", systemImage: "bell.slash")
        }

        Button {
            isShowingCustomMuteDialog = true
        } label: {
            Label("Mute Custom...", systemImage: "timer")
        }

        Button {
            Task {
                await updatePeerMute(interval: Self.muteForeverInterval)
            }
        } label: {
            Label("Mute Forever", systemImage: "bell.slash.fill")
        }

        Divider()

        Button(role: .destructive) {
            confirmHistoryAction(.clearHistory)
        } label: {
            Label("Clear History", systemImage: "trash")
        }
        Button(role: .destructive) {
            confirmHistoryAction(.deleteChat)
        } label: {
            Label("Delete Chat", systemImage: "trash")
        }
        Button(role: .destructive) {
            confirmHistoryAction(.deleteForEveryone)
        } label: {
            Label("Delete for Both", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var threadSearchInput: some View {
        if isThreadSearchActive {
            ChatSearchInputBar(
                query: $threadSearchQuery,
                isSearching: isThreadSearchSearching,
                onCancel: endThreadSearch
            )
            .onChange(of: threadSearchQuery) { _ in
                Task {
                    await debouncedThreadSearch()
                }
            }
        }
    }

    private var messageTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messageStack
            }
            .background(HSChatWallpaper())
            .onChange(of: messages.count) { _ in
                scrollAfterMessageCountChange(proxy: proxy)
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
            .onReceive(NotificationCenter.default.publisher(for: .hsNativeSyncDidChange)) { notification in
                applyInputActivities(from: notification)
                applyReadOutboxMaxID(from: notification)
                guard shouldRefreshThread(for: notification) else {
                    return
                }
                Task {
                    await refresh()
                }
            }
            .onChange(of: scrollTargetMessageID) { targetID in
                guard let targetID else {
                    return
                }
                proxy.scrollTo(targetID, anchor: .center)
                scrollTargetMessageID = nil
            }
        }
    }

    private var messageStack: some View {
        LazyVStack(spacing: 4) {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                statusBanner(statusMessage)
            }
            if !messages.isEmpty && hasMoreHistory {
                historyLoaderButton
            }
            ForEach(messageRows) { row in
                messageRow(row)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func statusBanner(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(HSTheme.trust)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var historyLoaderButton: some View {
        Button {
            Task {
                await loadOlder()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoadingOlder {
                    ProgressView()
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                }
                Text(isLoadingOlder ? "Loading earlier messages" : "Load Earlier Messages")
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isLoadingOlder)
        .id("history-loader")
    }

    @ViewBuilder
    private func messageRow(_ row: ChatThreadMessageRow) -> some View {
        let message = row.message
        if shouldShowDateSeparator(for: message, after: row.previousMessage) {
            ChatDateSeparatorView(date: message.sentAt)
        }
        if unreadSeparatorMessageID == message.id {
            ChatUnreadSeparatorView()
                .id(unreadSeparatorScrollID)
        }
        MessageBubble(
            message: displayMessage(message),
            replyPreview: message.replyToMessageID.flatMap { messagesByID[$0] },
            isGroup: displaysPeerAuthors,
            showsAvatar: shouldShowAvatar(for: message, row: row),
            isMergedWithPrevious: row.isMergedWithPrevious,
            isMergedWithNext: row.isMergedWithNext,
            isHighlighted: message.id == highlightedSearchMessageID,
            isSelecting: isSelectionMode,
            isSelected: selectedMessageIDs.contains(message.id),
            onReply: { beginReply(message) },
            onOpenReply: { messageID in Task { await openReplyTarget(messageID) } },
            onToggleSelection: { toggleSelection(message) },
            onBeginSelection: { beginSelection(message) },
            onEdit: { beginEdit(message) },
            onDelete: { Task { await delete(message) } },
            onForward: { forwardingMessage = message },
            onReact: { reaction in Task { await react(message, reaction: reaction) } },
            onPin: { Task { await pin(message) } },
            onCopyLink: { Task { await copyLink(message) } },
            onRetry: { Task { await retryFailedTextMessage(message) } },
            onOpenTextEntity: handleTextEntity,
            mediaDownloadState: mediaDownloadStates[message.id],
            onOpenMedia: { handleMediaAction(message) }
        )
        .id(message.id)
    }

    private func scrollAfterMessageCountChange(proxy: ScrollViewProxy) {
        if shouldScrollToUnreadSeparator, unreadSeparatorMessageID != nil {
            proxy.scrollTo(unreadSeparatorScrollID, anchor: .center)
            shouldScrollToUnreadSeparator = false
        } else if let preserved = preserveMessageID {
            proxy.scrollTo(preserved, anchor: .top)
            preserveMessageID = nil
        } else if shouldScrollToLatest, let last = messages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    @ViewBuilder
    private var bottomInteractionBar: some View {
        if isSelectionMode {
            MessageSelectionToolbar(
                selectedCount: selectedMessageIDs.count,
                canCopy: selectedMessagesContainText,
                onCancel: clearSelection,
                onCopy: copySelectedMessages,
                onForward: {
                    isShowingSelectionForwardSheet = true
                },
                onDelete: {
                    isShowingSelectionDeleteConfirmation = true
                }
            )
        } else if isThreadSearchActive {
            ChatSearchNavigationPanel(
                currentDisplayIndex: currentThreadSearchDisplayIndex,
                totalCount: threadSearchResults.count,
                didSearch: didPerformThreadSearch,
                canOpenResults: !threadSearchResults.isEmpty,
                canNavigateEarlier: canNavigateThreadSearchEarlier,
                canNavigateLater: canNavigateThreadSearchLater,
                onEarlier: { Task { await navigateThreadSearch(.earlier) } },
                onLater: { Task { await navigateThreadSearch(.later) } },
                onOpenResults: { isShowingThreadSearchResults = true }
            )
        } else {
            if linkPreview != nil || isLoadingLinkPreview {
                ChatComposerLinkPreviewBar(
                    preview: linkPreview,
                    isLoading: isLoadingLinkPreview,
                    onDismiss: dismissLinkPreview
                )
            }
            ChatComposerView(
                draft: $draft,
                isReplying: replyingToMessage != nil || draftReplyToMessageID != nil,
                replyTitle: replyTitle,
                replyPreview: replyPreview,
                onClearReply: clearReply,
                onAttachment: {
                    isShowingAttachmentSheet = true
                },
                onVoiceRecorded: sendVoiceRecording,
                onVoiceError: { message in
                    statusMessage = nil
                    errorMessage = message
                },
                onVoiceRecordingStateChanged: handleVoiceRecordingStateChanged,
                onSend: {
                    Task {
                        await send()
                    }
                }
            )
        }
    }

    private var replyTitle: String {
        if let replyingToMessage {
            return "Replying to \(replyingToMessage.authorName)"
        }
        if let draftReplyToMessageID {
            return "Replying to message #\(draftReplyToMessageID)"
        }
        return "Replying"
    }

    private var replyPreview: String {
        if let replyingToMessage {
            return replyingToMessage.text.isEmpty ? "Message #\(replyingToMessage.id)" : replyingToMessage.text
        }
        return "Original message may be outside the loaded page."
    }

    private var currentThreadSearchResult: ChatSearchResult? {
        guard let currentThreadSearchIndex, threadSearchResults.indices.contains(currentThreadSearchIndex) else {
            return nil
        }
        return threadSearchResults[currentThreadSearchIndex]
    }

    private var currentThreadSearchDisplayIndex: Int? {
        guard let currentThreadSearchIndex, !threadSearchResults.isEmpty else {
            return nil
        }
        return threadSearchResults.count - currentThreadSearchIndex
    }

    private var canNavigateThreadSearchEarlier: Bool {
        guard let currentThreadSearchIndex else {
            return false
        }
        return currentThreadSearchIndex > 0
    }

    private var canNavigateThreadSearchLater: Bool {
        guard let currentThreadSearchIndex else {
            return false
        }
        return currentThreadSearchIndex < threadSearchResults.count - 1
    }

    private func beginThreadSearch() {
        clearSelection()
        isThreadSearchActive = true
        shouldScrollToLatest = false
        statusMessage = nil
    }

    private func beginThreadSearch(query: String) {
        beginThreadSearch()
        threadSearchQuery = query
        Task {
            await performThreadSearch()
        }
    }

    private func endThreadSearch() {
        isThreadSearchActive = false
        threadSearchQuery = ""
        threadSearchResults = []
        currentThreadSearchIndex = nil
        highlightedSearchMessageID = nil
        didPerformThreadSearch = false
        isShowingThreadSearchResults = false
    }

    private func debouncedThreadSearch() async {
        let current = threadSearchQuery
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard current == threadSearchQuery else {
            return
        }
        await performThreadSearch()
    }

    private func performThreadSearch() async {
        guard let session = authStore.session else {
            return
        }
        let trimmed = threadSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            threadSearchResults = []
            currentThreadSearchIndex = nil
            highlightedSearchMessageID = nil
            didPerformThreadSearch = false
            errorMessage = nil
            return
        }

        isThreadSearchSearching = true
        didPerformThreadSearch = true
        let previousMessageID = currentThreadSearchResult?.messageID
        defer { isThreadSearchSearching = false }

        do {
            let found = try await authStore.api.searchMessages(dialogID: chat.id, query: trimmed, limit: 100, session: session)
                .map(ChatSearchResult.init)
                .sorted { lhs, rhs in
                    if lhs.sentAt == rhs.sentAt {
                        return lhs.messageID < rhs.messageID
                    }
                    return lhs.sentAt < rhs.sentAt
                }

            threadSearchResults = found
            if let previousMessageID, let retainedIndex = found.firstIndex(where: { $0.messageID == previousMessageID }) {
                currentThreadSearchIndex = retainedIndex
            } else {
                currentThreadSearchIndex = found.indices.last
            }
            if let result = currentThreadSearchResult {
                await openSearchResult(result)
            } else {
                highlightedSearchMessageID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func navigateThreadSearch(_ direction: ThreadSearchNavigationDirection) async {
        guard let currentThreadSearchIndex else {
            return
        }

        let nextIndex: Int?
        switch direction {
        case .earlier:
            nextIndex = currentThreadSearchIndex > 0 ? currentThreadSearchIndex - 1 : nil
        case .later:
            nextIndex = currentThreadSearchIndex < threadSearchResults.count - 1 ? currentThreadSearchIndex + 1 : nil
        }

        guard let nextIndex, threadSearchResults.indices.contains(nextIndex) else {
            return
        }
        self.currentThreadSearchIndex = nextIndex
        await openSearchResult(threadSearchResults[nextIndex])
    }

    private func selectThreadSearchResult(_ result: ChatSearchResult) {
        if let index = threadSearchResults.firstIndex(where: { $0.messageID == result.messageID }) {
            currentThreadSearchIndex = index
        }
        Task {
            await openSearchResult(result)
        }
    }

    private func applyInputActivities(from notification: Notification) {
        guard let activity = HSInputActivityNotification.activities(from: notification)
            .last(where: { $0.dialogID == chat.id && $0.userID != authStore.session?.userID }) else {
            return
        }
        if activity.kind == .cancel || activity.expiresAt <= Date() {
            remoteInputActivity = nil
            inputActivityCleanupTask?.cancel()
            return
        }
        remoteInputActivity = activity
        scheduleInputActivityExpiry(activity)
    }

    private func scheduleInputActivityExpiry(_ activity: HSInputActivity) {
        inputActivityCleanupTask?.cancel()
        inputActivityCleanupTask = Task {
            let delay = max(0, activity.expiresAt.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                guard remoteInputActivity == activity else {
                    return
                }
                remoteInputActivity = nil
            }
        }
    }

    private func shouldRefreshThread(for notification: Notification) -> Bool {
        if HSInputActivityNotification.isTypingOnly(notification) {
            return false
        }
        if let fullRefresh = notification.userInfo?["full_refresh"] as? Bool, fullRefresh {
            return true
        }
        guard let dialogIDs = notification.userInfo?["dialog_ids"] as? [Int64],
              !dialogIDs.isEmpty else {
            return true
        }
        return dialogIDs.contains(chat.id)
    }

    private func applyReadOutboxMaxID(from notification: Notification) {
        guard let readOutboxMaxIDs = notification.userInfo?["read_outbox_max_ids"] as? [Int64: Int64],
              let maxID = readOutboxMaxIDs[chat.id] else {
            return
        }
        readOutboxMaxID = max(readOutboxMaxID, maxID)
        publishLocalOutboxState()
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            preserveMessageID = nil
            shouldScrollToLatest = true
            async let initialPageTask = loadInitialMessages(session: session)
            async let readStateTask = authStore.api.dialogReadState(dialogID: chat.id, session: session)
            let initialPage = try await initialPageTask
            if let readState = try? await readStateTask {
                applyReadState(readState)
            }
            let loaded = initialPage.messages
            if !didResolveInitialUnreadSeparator {
                unreadSeparatorMessageID = initialUnreadSeparatorMessageID(in: loaded)
                shouldScrollToUnreadSeparator = unreadSeparatorMessageID != nil
                didResolveInitialUnreadSeparator = true
                if shouldScrollToUnreadSeparator {
                    shouldScrollToLatest = false
                }
            }
            messages = mergedServerAndLocalMessages(serverMessages: loaded)
            publishLocalOutboxState()
            selectedMessageIDs.formIntersection(Set(messages.map(\.id)))
            restoreDraftReplyTarget()
            hasMoreHistory = initialPage.hasMoreHistory
            errorMessage = nil
            await markRead(messages: loaded)
            await refreshAutomaticDownloadContactIDsIfNeeded(session: session)
            startAutomaticMediaDownloads(for: loaded, session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadOlder() async {
        guard let session = authStore.session, let oldest = messages.first, !isLoadingOlder, hasMoreHistory else {
            return
        }
        isLoadingOlder = true
        preserveMessageID = oldest.id
        shouldScrollToLatest = false
        defer {
            isLoadingOlder = false
        }
        do {
            let loaded = try await authStore.api.messages(dialogID: chat.id, beforeID: oldest.id, limit: pageSize, session: session)
            let existingIDs = Set(messages.map(\.id))
            let olderMessages = loaded.filter { !existingIDs.contains($0.id) }
            if olderMessages.isEmpty {
                hasMoreHistory = false
            } else {
                messages.insert(contentsOf: olderMessages, at: 0)
                hasMoreHistory = loaded.count >= pageSize
                await refreshAutomaticDownloadContactIDsIfNeeded(session: session)
                startAutomaticMediaDownloads(for: olderMessages, session: session)
            }
            errorMessage = nil
        } catch {
            preserveMessageID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func refreshReadState(session: HSUserSession) async {
        guard let readState = try? await authStore.api.dialogReadState(dialogID: chat.id, session: session) else {
            return
        }
        applyReadState(readState)
    }

    private func applyReadState(_ readState: HSDialogReadState) {
        guard readState.dialogID == chat.id else {
            return
        }
        readOutboxMaxID = max(readOutboxMaxID, readState.readOutboxMaxID)
        publishLocalOutboxState()
    }

    private func openSearchResult(_ result: ChatSearchResult) async {
        if isResolvingSearchResult {
            return
        }
        isResolvingSearchResult = true
        defer { isResolvingSearchResult = false }
        shouldScrollToLatest = false

        do {
            try await ensureMessageLoaded(messageID: result.messageID)
            guard messages.contains(where: { $0.id == result.messageID }) else {
                errorMessage = "Message is no longer available in this chat."
                return
            }
            highlightedSearchMessageID = result.messageID
            scrollTargetMessageID = result.messageID
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureMessageLoaded(messageID: Int64) async throws {
        guard let session = authStore.session else {
            return
        }
        if messages.contains(where: { $0.id == messageID }) {
            return
        }
        if messages.isEmpty {
            let loaded = try await authStore.api.messages(dialogID: chat.id, limit: pageSize, session: session)
            messages = loaded
            hasMoreHistory = loaded.count >= pageSize
            await refreshAutomaticDownloadContactIDsIfNeeded(session: session)
            startAutomaticMediaDownloads(for: loaded, session: session)
        }

        var pageCount = 0
        while !messages.contains(where: { $0.id == messageID }), hasMoreHistory, pageCount < 40 {
            guard let oldest = messages.first else {
                return
            }
            let loaded = try await authStore.api.messages(dialogID: chat.id, beforeID: oldest.id, limit: pageSize, session: session)
            let existingIDs = Set(messages.map(\.id))
            let olderMessages = loaded.filter { !existingIDs.contains($0.id) }
            if olderMessages.isEmpty {
                hasMoreHistory = false
                return
            }
            messages.insert(contentsOf: olderMessages, at: 0)
            hasMoreHistory = loaded.count >= pageSize
            await refreshAutomaticDownloadContactIDsIfNeeded(session: session)
            startAutomaticMediaDownloads(for: olderMessages, session: session)
            pageCount += 1
        }
    }

    private func openReplyTarget(_ messageID: Int64) async {
        if isResolvingSearchResult {
            return
        }
        isResolvingSearchResult = true
        defer { isResolvingSearchResult = false }
        shouldScrollToLatest = false

        do {
            try await ensureMessageLoaded(messageID: messageID)
            guard messages.contains(where: { $0.id == messageID }) else {
                errorMessage = "Original message is no longer available in this chat."
                return
            }
            highlightedSearchMessageID = messageID
            scrollTargetMessageID = messageID
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openSharedMediaMessage(_ message: HSMessage) async {
        if isResolvingSearchResult {
            return
        }
        isResolvingSearchResult = true
        defer { isResolvingSearchResult = false }
        shouldScrollToLatest = false

        do {
            try await ensureMessageLoaded(messageID: message.id)
            guard messages.contains(where: { $0.id == message.id }) else {
                errorMessage = "Message is no longer available in this chat."
                return
            }
            highlightedSearchMessageID = message.id
            scrollTargetMessageID = message.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleMediaAction(_ message: HSMessage) {
        if message.isOutgoing, message.id < 0 {
            switch message.deliveryState {
            case .sending:
                cancelAttachmentUpload()
            case .failed:
                retryFailedAttachmentMessage(message)
            case .sent, .read:
                break
            }
            return
        }
        if mediaDownloadStates[message.id]?.isDownloading == true {
            cancelMediaDownload(message)
            return
        }
        openMedia(message)
    }

    private func openMedia(_ message: HSMessage) {
        guard let media = message.media else {
            return
        }
        if let url = downloadedMediaURLs[message.id] {
            if FileManager.default.fileExists(atPath: url.path) {
                mediaPreviewItem = HSMediaPreviewItem(id: message.id, url: url, media: media, image: previewImage(for: media, url: url))
                return
            }
            downloadedMediaURLs[message.id] = nil
            mediaDownloadStates[message.id] = nil
        }
        do {
            if let cachedURL = try HSMediaCacheStore.shared.cachedURL(for: media, messageID: message.id) {
                downloadedMediaURLs[message.id] = cachedURL
                mediaDownloadStates[message.id] = .downloaded
                mediaPreviewItem = HSMediaPreviewItem(id: message.id, url: cachedURL, media: media, image: previewImage(for: media, url: cachedURL))
                return
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard media.location != nil else {
            errorMessage = "这条媒体消息缺少可下载的文件位置。"
            return
        }
        guard let session = authStore.session else {
            errorMessage = HSAPIError.missingSession.localizedDescription
            return
        }
        if mediaDownloadTasks[message.id] != nil {
            return
        }
        startMediaDownload(message, media: media, session: session, openWhenFinished: true, isAutomatic: false)
    }

    private func startAutomaticMediaDownloads(for candidateMessages: [HSMessage], session: HSUserSession) {
        let settings = HSMediaAutoDownloadSettings.load()
        if scenePhase != .active, !settings.allowsBackgroundAutomaticDownloads() {
            return
        }
        let network = HSMediaNetworkPathMonitor.shared.currentNetworkType ?? .wifi

        var enqueued = 0
        for message in candidateMessages.reversed() {
            let peerType = automaticDownloadPeerType(for: message)
            guard enqueued < 8,
                  !message.isOutgoing,
                  mediaDownloadTasks[message.id] == nil,
                  mediaDownloadStates[message.id] == nil,
                  downloadedMediaURLs[message.id] == nil,
                  let media = message.media,
                  media.location != nil,
                  settings.allowsAutomaticDownload(media: media, network: network, peerType: peerType) else {
                continue
            }

            if let cachedURL = try? HSMediaCacheStore.shared.cachedURL(for: media, messageID: message.id) {
                downloadedMediaURLs[message.id] = cachedURL
                mediaDownloadStates[message.id] = .downloaded
                continue
            }

            startMediaDownload(message, media: media, session: session, openWhenFinished: false, isAutomatic: true)
            enqueued += 1
        }
    }

    private func refreshAutomaticDownloadContactIDsIfNeeded(session: HSUserSession) async {
        guard !didLoadAutoDownloadContacts else {
            return
        }
        do {
            let contacts = try await authStore.api.contacts(session: session)
            autoDownloadContactIDs = Set(contacts.map(\.id))
        } catch {
            autoDownloadContactIDs = []
        }
        didLoadAutoDownloadContacts = true
    }

    private func automaticDownloadPeerType(for message: HSMessage) -> HSMediaAutoDownloadPeerType {
        if case .channel = mode {
            return .channel
        }
        if chat.isCircle {
            return autoDownloadContactIDs.contains(message.authorID) ? .contact : .group
        }
        if autoDownloadContactIDs.contains(chat.id) || autoDownloadContactIDs.contains(message.authorID) {
            return .contact
        }
        return .otherPrivate
    }

    private func startMediaDownload(_ message: HSMessage, media: HSMessageMedia, session: HSUserSession, openWhenFinished: Bool, isAutomatic: Bool) {
        guard mediaDownloadTasks[message.id] == nil else {
            return
        }
        mediaDownloadStates[message.id] = .downloading(progress: nil)
        let task = Task {
            await downloadMedia(message, media: media, session: session, openWhenFinished: openWhenFinished, isAutomatic: isAutomatic)
        }
        mediaDownloadTasks[message.id] = task
    }

    private func downloadMedia(_ message: HSMessage, media: HSMessageMedia, session: HSUserSession, openWhenFinished: Bool, isAutomatic: Bool) async {
        do {
            let data = try await authStore.api.downloadMedia(
                media,
                session: session,
                progress: { update in
                    Task { @MainActor in
                        guard mediaDownloadTasks[message.id] != nil else {
                            return
                        }
                        mediaDownloadStates[message.id] = .downloading(progress: update.fractionCompleted)
                    }
                }
            )
            try Task.checkCancellation()
            let url = try HSMediaCacheStore.shared.store(data: data, media: media, messageID: message.id)
            downloadedMediaURLs[message.id] = url
            mediaDownloadStates[message.id] = .downloaded
            mediaDownloadTasks[message.id] = nil
            if openWhenFinished {
                mediaPreviewItem = HSMediaPreviewItem(id: message.id, url: url, media: media, image: previewImage(for: media, url: url))
            }
            errorMessage = nil
        } catch is CancellationError {
            mediaDownloadTasks[message.id] = nil
            mediaDownloadStates[message.id] = nil
            if !isAutomatic {
                statusMessage = "Media download canceled."
            }
            errorMessage = nil
        } catch {
            mediaDownloadTasks[message.id] = nil
            if isAutomatic {
                mediaDownloadStates[message.id] = nil
            } else {
                mediaDownloadStates[message.id] = .failed
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cancelMediaDownload(_ message: HSMessage) {
        mediaDownloadTasks[message.id]?.cancel()
        mediaDownloadTasks[message.id] = nil
        mediaDownloadStates[message.id] = nil
        statusMessage = "Media download canceled."
        errorMessage = nil
    }

    private func previewImage(for media: HSMessageMedia, url: URL) -> UIImage? {
        switch media.kind {
        case .photo, .gif, .sticker:
            return UIImage(contentsOfFile: url.path)
        case .video, .audio, .voice, .webpage, .file, .unknown:
            return nil
        }
    }

    private func loadDraft() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let drafts = try await authStore.api.drafts(session: session)
            guard let savedDraft = drafts.first(where: { $0.dialogID == chat.id }) else {
                return
            }
            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft = savedDraft.text
            }
            draftReplyToMessageID = savedDraft.replyToMessageID
            restoreDraftReplyTarget()
        } catch {
            // Drafts are helpful continuity, not a blocker for reading the thread.
        }
    }

    private func scheduleLinkPreviewRefresh(for text: String) {
        let detectedURL = Self.firstURLString(in: text)
        guard let detectedURL else {
            clearLinkPreviewState()
            return
        }

        if dismissedLinkPreviewURL != detectedURL {
            dismissedLinkPreviewURL = nil
        }
        guard dismissedLinkPreviewURL != detectedURL else {
            linkPreviewTask?.cancel()
            linkPreviewTask = nil
            linkPreview = nil
            linkPreviewSourceURL = detectedURL
            isLoadingLinkPreview = false
            return
        }
        if linkPreviewSourceURL == detectedURL, linkPreview != nil {
            return
        }

        linkPreviewTask?.cancel()
        linkPreviewSourceURL = detectedURL
        linkPreview = nil
        isLoadingLinkPreview = true
        linkPreviewTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else {
                return
            }
            guard let session = authStore.session else {
                await MainActor.run {
                    if linkPreviewSourceURL == detectedURL {
                        isLoadingLinkPreview = false
                    }
                }
                return
            }
            do {
                let preview = try await authStore.api.webPagePreview(text: text, session: session)
                await MainActor.run {
                    guard Self.firstURLString(in: draft) == detectedURL,
                          dismissedLinkPreviewURL != detectedURL else {
                        return
                    }
                    linkPreview = preview
                    linkPreviewSourceURL = detectedURL
                    isLoadingLinkPreview = false
                }
            } catch {
                await MainActor.run {
                    if linkPreviewSourceURL == detectedURL {
                        linkPreview = nil
                        isLoadingLinkPreview = false
                    }
                }
            }
        }
    }

    private func dismissLinkPreview() {
        let url = linkPreviewSourceURL ?? Self.firstURLString(in: draft)
        dismissedLinkPreviewURL = url
        linkPreviewTask?.cancel()
        linkPreviewTask = nil
        linkPreview = nil
        isLoadingLinkPreview = false
    }

    private func clearLinkPreviewState() {
        linkPreviewTask?.cancel()
        linkPreviewTask = nil
        linkPreview = nil
        linkPreviewSourceURL = nil
        dismissedLinkPreviewURL = nil
        isLoadingLinkPreview = false
    }

    private static func firstURLString(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let nsText = trimmed as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = linkDetector?.firstMatch(in: trimmed, options: [], range: range) else {
            return nil
        }
        if let url = match.url {
            return url.absoluteString
        }
        return nsText.substring(with: match.range)
    }

    private func handleDraftInputActivity(_ value: String) {
        guard !isSavedMessagesMode else {
            return
        }
        let isEmpty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Task {
            await sendInputActivity(isEmpty ? .cancel : .typing)
        }
    }

    private func handleVoiceRecordingStateChanged(_ isRecording: Bool) {
        Task {
            await sendInputActivity(isRecording ? .recordingVoice : .cancel, force: true)
        }
    }

    private func sendInputActivity(_ kind: HSInputActivityKind, progress: Int? = nil, force: Bool = false) async {
        guard !isSavedMessagesMode, let session = authStore.session else {
            return
        }
        if !force, shouldThrottleInputActivity(kind) {
            return
        }
        do {
            _ = try await authStore.api.setTyping(
                dialogID: chat.id,
                activity: kind,
                progress: progress,
                session: session
            )
            lastSentInputActivity = (kind, Date())
        } catch {
            // Input activity is transient; failed pings should not interrupt composing.
        }
    }

    private func shouldThrottleInputActivity(_ kind: HSInputActivityKind) -> Bool {
        guard kind != .cancel, let lastSentInputActivity else {
            return false
        }
        return lastSentInputActivity.kind == kind
            && Date().timeIntervalSince(lastSentInputActivity.date) < Self.inputActivityThrottle
    }

    private func uploadInputActivity(for pending: HSPendingAttachmentUpload) -> HSInputActivityKind {
        switch mediaKind(from: pending.mediaKind) {
        case .photo, .gif, .sticker:
            return .uploadingPhoto
        case .video:
            return .uploadingVideo
        case .voice:
            return .uploadingVoice
        case .audio:
            return .uploadingVoice
        case .file, .webpage, .unknown:
            return .uploadingFile
        }
    }

    private func localOutgoingMessage(text: String, replyToMessageID: Int64?, session: HSUserSession) -> HSMessage {
        HSMessage(
            id: nextLocalMessageID(),
            dialogID: chat.id,
            authorID: session.userID,
            authorName: session.displayName.isEmpty ? "You" : session.displayName,
            text: text,
            kind: nil,
            sentAt: Date(),
            isOutgoing: true,
            deliveryState: .sending,
            replyToMessageID: replyToMessageID
        )
    }

    private func nextLocalMessageID() -> Int64 {
        var candidate = -Int64(Date().timeIntervalSince1970 * 1_000_000)
        let existingIDs = Set(messages.map(\.id))
        while existingIDs.contains(candidate) {
            candidate -= 1
        }
        return candidate
    }

    private func completePendingMessage(localID: Int64, sent: HSMessage) {
        guard let index = messages.firstIndex(where: { $0.id == localID }) else {
            return
        }
        messages.remove(at: index)
        guard !messages.contains(where: { $0.id == sent.id }) else {
            publishLocalOutboxState()
            return
        }
        messages.append(sent)
        publishLocalOutboxState()
    }

    private func localAttachmentMessage(from pending: HSPendingAttachmentUpload, session: HSUserSession) -> HSMessage {
        HSMessage(
            id: pending.localMessageID,
            dialogID: chat.id,
            authorID: session.userID,
            authorName: session.displayName.isEmpty ? "You" : session.displayName,
            text: pending.caption,
            kind: "media",
            sentAt: Date(),
            isOutgoing: true,
            deliveryState: .sending,
            replyToMessageID: pending.replyToMessageID,
            media: HSMessageMedia(
                kind: mediaKind(from: pending.mediaKind),
                fileName: pending.fileName,
                mimeType: pending.mimeType,
                size: Int64(pending.data.count),
                width: nil,
                height: nil,
                duration: pending.duration,
                waveform: pending.waveform
            )
        )
    }

    private func mediaKind(from rawValue: String) -> HSMessageMedia.MediaKind {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "photo", "image":
            return .photo
        case "video":
            return .video
        case "gif":
            return .gif
        case "audio", "music":
            return .audio
        case "voice":
            return .voice
        case "sticker":
            return .sticker
        case "file", "document":
            return .file
        default:
            return .unknown
        }
    }

    private func mergedServerAndLocalMessages(serverMessages: [HSMessage]) -> [HSMessage] {
        let serverIDs = Set(serverMessages.map(\.id))
        let retainedLocalMessages = localOutgoingMessages.filter { !serverIDs.contains($0.id) }
        return (serverMessages + retainedLocalMessages).sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.id < rhs.id
            }
            return lhs.sentAt < rhs.sentAt
        }
    }

    private func publishLocalOutboxState() {
        guard !isSavedMessagesMode else {
            postLocalOutboxClear()
            return
        }
        guard let lastMessage = messages.last else {
            postLocalOutboxClear()
            return
        }
        let displayedMessage = displayMessage(lastMessage)
        guard displayedMessage.isOutgoing else {
            postLocalOutboxClear()
            return
        }
        let preview = chatListPreview(for: displayedMessage)
        NotificationCenter.default.post(
            name: .hsChatLocalOutboxDidChange,
            object: nil,
            userInfo: [
                HSChatLocalOutboxNotification.dialogID: chat.id,
                HSChatLocalOutboxNotification.messageID: displayedMessage.id,
                HSChatLocalOutboxNotification.preview: preview,
                HSChatLocalOutboxNotification.deliveryState: displayedMessage.deliveryState.rawValue,
                HSChatLocalOutboxNotification.updatedAt: displayedMessage.sentAt
            ]
        )
    }

    private func postLocalOutboxClear() {
        NotificationCenter.default.post(
            name: .hsChatLocalOutboxDidChange,
            object: nil,
            userInfo: [
                HSChatLocalOutboxNotification.dialogID: chat.id,
                HSChatLocalOutboxNotification.isClear: true
            ]
        )
    }

    private func chatListPreview(for message: HSMessage) -> String {
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
        guard let media = message.media else {
            return "Message"
        }
        switch media.kind {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .gif:
            return "GIF"
        case .voice:
            return "Voice message"
        case .audio:
            return "Audio"
        case .file:
            if let fileName = media.fileName, !fileName.isEmpty {
                return fileName
            }
            return "File"
        case .sticker:
            return "Sticker"
        case .webpage:
            return media.webPage?.title
                ?? media.webPage?.siteName
                ?? media.webPage?.displayURL
                ?? media.webPage?.url
                ?? "Link Preview"
        case .unknown:
            return "Attachment"
        }
    }

    private func saveDraft() async {
        guard let session = authStore.session else {
            return
        }
        _ = try? await authStore.api.saveDraft(
            dialogID: chat.id,
            text: draft,
            replyToMessageID: activeReplyToMessageID,
            disableWebPagePreview: dismissedLinkPreviewURL == Self.firstURLString(in: draft),
            session: session
        )
    }

    private func send() async {
        guard let session = authStore.session else {
            return
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        let replyID = activeReplyToMessageID
        let sentWithoutWebPage = dismissedLinkPreviewURL == Self.firstURLString(in: text)
        let pendingMessage = localOutgoingMessage(
            text: text,
            replyToMessageID: replyID,
            session: session
        )
        draft = ""
        replyingToMessage = nil
        draftReplyToMessageID = nil
        clearLinkPreviewState()
        await sendInputActivity(.cancel, force: true)
        shouldScrollToLatest = true
        messages.append(pendingMessage)
        publishLocalOutboxState()

        await sendPendingTextMessage(pendingMessage, disableWebPagePreview: sentWithoutWebPage)
    }

    private func sendPendingTextMessage(_ pendingMessage: HSMessage, disableWebPagePreview: Bool) async {
        guard let session = authStore.session else {
            replace(messageID: pendingMessage.id, with: pendingMessage.withDeliveryState(.failed))
            errorMessage = HSAPIError.missingSession.localizedDescription
            return
        }
        do {
            let sent = try await authStore.api.sendMessage(
                dialogID: chat.id,
                text: pendingMessage.text,
                replyToMessageID: pendingMessage.replyToMessageID,
                disableWebPagePreview: disableWebPagePreview,
                session: session
            )
            completePendingMessage(localID: pendingMessage.id, sent: sent)
            _ = try? await authStore.api.saveDraft(dialogID: chat.id, text: "", replyToMessageID: nil, session: session)
            errorMessage = nil
            await markRead(messages: messages)
            await refreshReadState(session: session)
        } catch {
            replace(messageID: pendingMessage.id, with: pendingMessage.withDeliveryState(.failed))
            errorMessage = error.localizedDescription
        }
    }

    private func retryFailedTextMessage(_ message: HSMessage) async {
        guard message.isOutgoing, message.deliveryState == .failed else {
            return
        }
        if message.kind == "media" {
            retryFailedAttachmentMessage(message)
            return
        }
        let pendingMessage = message.withDeliveryState(.sending)
        replace(messageID: message.id, with: pendingMessage)
        shouldScrollToLatest = true
        publishLocalOutboxState()
        await sendPendingTextMessage(pendingMessage, disableWebPagePreview: false)
    }

    private func handleAttachment(_ option: ChatAttachmentOption) {
        let detail: String
        switch option {
        case .gallery:
            isShowingPhotoPicker = true
            return
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                statusMessage = "Camera is not available on this device."
                errorMessage = nil
                return
            }
            isShowingCameraCapture = true
            return
        case .file:
            isShowingFileImporter = true
            return
        case .location:
            detail = "Location messages need the existing location media contract mapped into the native API client."
        case .contact:
            detail = "Contact sharing needs the existing contact media contract mapped into the native API client."
        case .poll:
            detail = "Poll creation needs the existing poll media contract mapped into the native API client."
        case .todo:
            detail = "Todo messages need the existing task message contract mapped into the native API client."
        case .quickReply:
            detail = "Quick replies need the existing business quick-reply contract mapped into the native API client."
        }
        statusMessage = detail
        errorMessage = nil
    }

    private func sendCameraCaptureResult(_ result: HSCameraCaptureResult) {
        startAttachmentUpload(
            data: result.data,
            fileName: result.fileName,
            mimeType: result.mimeType,
            mediaKind: result.mediaKind
        )
    }

    private func sendVoiceRecording(_ recording: HSVoiceRecording) {
        startAttachmentUpload(
            data: recording.data,
            fileName: recording.fileName,
            mimeType: recording.mimeType,
            mediaKind: "voice",
            duration: recording.duration,
            waveform: recording.waveform
        )
    }

    private func sendPhotoPickerItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw HSAPIError.server(code: "MEDIA_LOAD_FAILED", message: "无法读取选择的媒体。")
            }
            let contentType = item.supportedContentTypes.first ?? .data
            let fileExtension = contentType.preferredFilenameExtension ?? "dat"
            let mediaKind = contentType.conforms(to: .movie) ? "video" : "photo"
            let mimeType = contentType.preferredMIMEType ?? (mediaKind == "photo" ? "image/jpeg" : "video/mp4")
            startAttachmentUpload(
                data: data,
                fileName: "hsgram-\(Int(Date().timeIntervalSince1970)).\(fileExtension)",
                mimeType: mimeType,
                mediaKind: mediaKind
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendImportedFile(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else {
                return
            }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
                ?? UTType(filenameExtension: url.pathExtension)
                ?? .data
            startAttachmentUpload(
                data: data,
                fileName: url.lastPathComponent,
                mimeType: contentType.preferredMIMEType ?? "application/octet-stream",
                mediaKind: contentType.conforms(to: .movie) ? "video" : "file"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startAttachmentUpload(
        data: Data,
        fileName: String,
        mimeType: String,
        mediaKind: String,
        duration: Double? = nil,
        waveform: Data? = nil
    ) {
        guard attachmentUploadTask == nil else {
            statusMessage = "Finish or cancel the current upload before sending another file."
            errorMessage = nil
            return
        }
        let pending = HSPendingAttachmentUpload(
            id: UUID(),
            localMessageID: nextLocalMessageID(),
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            mediaKind: mediaKind,
            duration: duration,
            waveform: waveform,
            caption: draft.trimmingCharacters(in: .whitespacesAndNewlines),
            replyToMessageID: activeReplyToMessageID,
            replyMessage: replyingToMessage
        )
        beginAttachmentUpload(pending)
    }

    private func beginAttachmentUpload(_ pending: HSPendingAttachmentUpload) {
        pendingAttachmentUpload = pending
        attachmentUploadFailed = false
        mediaDownloadStates[pending.localMessageID] = .downloading(progress: 0)
        statusMessage = nil
        errorMessage = nil
        draft = ""
        replyingToMessage = nil
        draftReplyToMessageID = nil
        if let session = authStore.session {
            let localMessage = localAttachmentMessage(from: pending, session: session)
            if messages.contains(where: { $0.id == pending.localMessageID }) {
                replace(messageID: pending.localMessageID, with: localMessage)
            } else {
                shouldScrollToLatest = true
                messages.append(localMessage)
            }
            publishLocalOutboxState()
        }
        let task = Task {
            await performAttachmentUpload(pending)
        }
        attachmentUploadTask = task
    }

    private func performAttachmentUpload(_ pending: HSPendingAttachmentUpload) async {
        guard let session = authStore.session else {
            attachmentUploadFailed = true
            if let localMessage = messages.first(where: { $0.id == pending.localMessageID }) {
                replace(messageID: pending.localMessageID, with: localMessage.withDeliveryState(.failed))
            }
            publishLocalOutboxState()
            mediaDownloadStates[pending.localMessageID] = .failed
            attachmentUploadTask = nil
            errorMessage = HSAPIError.missingSession.localizedDescription
            return
        }
        defer {
            if pendingAttachmentUpload?.id == pending.id {
                attachmentUploadTask = nil
            }
        }
        do {
            let sent = try await authStore.api.sendMedia(
                dialogID: chat.id,
                fileName: pending.fileName,
                mimeType: pending.mimeType,
                data: pending.data,
                mediaKind: pending.mediaKind,
                caption: pending.caption,
                replyToMessageID: pending.replyToMessageID,
                duration: pending.duration,
                waveform: pending.waveform,
                session: session,
                progress: { update in
                    Task { @MainActor in
                        updateAttachmentUploadProgress(update, uploadID: pending.id)
                    }
                }
            )
            await sendInputActivity(.cancel, force: true)
            shouldScrollToLatest = true
            completePendingMessage(localID: pending.localMessageID, sent: sent)
            pendingAttachmentUpload = nil
            mediaDownloadStates.removeValue(forKey: pending.localMessageID)
            attachmentUploadFailed = false
            attachmentUploadTask = nil
            statusMessage = nil
            errorMessage = nil
            _ = try? await authStore.api.saveDraft(dialogID: chat.id, text: "", replyToMessageID: nil, session: session)
            await markRead(messages: messages)
            await refreshReadState(session: session)
        } catch is CancellationError {
            if pendingAttachmentUpload?.id == pending.id {
                restoreComposer(from: pending)
                pendingAttachmentUpload = nil
                mediaDownloadStates.removeValue(forKey: pending.localMessageID)
                messages.removeAll { $0.id == pending.localMessageID }
                publishLocalOutboxState()
                attachmentUploadFailed = false
                statusMessage = "Media upload canceled."
                errorMessage = nil
                Task {
                    await sendInputActivity(.cancel, force: true)
                }
            }
        } catch {
            if pendingAttachmentUpload?.id == pending.id {
                attachmentUploadFailed = true
                replace(messageID: pending.localMessageID, with: localAttachmentMessage(from: pending, session: session).withDeliveryState(.failed))
                mediaDownloadStates[pending.localMessageID] = .failed
                publishLocalOutboxState()
            }
            statusMessage = nil
            errorMessage = error.localizedDescription
            await sendInputActivity(.cancel, force: true)
        }
    }

    private func updateAttachmentUploadProgress(_ progress: HSMediaTransferProgress, uploadID: UUID) {
        guard pendingAttachmentUpload?.id == uploadID, !attachmentUploadFailed else {
            return
        }
        if let localMessageID = pendingAttachmentUpload?.localMessageID {
            mediaDownloadStates[localMessageID] = .downloading(progress: progress.fractionCompleted)
        }
        guard let pending = pendingAttachmentUpload else {
            return
        }
        let percent = progress.fractionCompleted.map { Int(($0 * 100).rounded()) }
        Task {
            await sendInputActivity(uploadInputActivity(for: pending), progress: percent)
        }
    }

    private func retryFailedAttachmentMessage(_ message: HSMessage) {
        guard let pending = pendingAttachmentUpload,
              pending.localMessageID == message.id,
              attachmentUploadTask == nil else {
            return
        }
        beginAttachmentUpload(pending)
    }

    private func cancelAttachmentUpload() {
        guard let pending = pendingAttachmentUpload else {
            return
        }
        attachmentUploadTask?.cancel()
        attachmentUploadTask = nil
        restoreComposer(from: pending)
        pendingAttachmentUpload = nil
        mediaDownloadStates.removeValue(forKey: pending.localMessageID)
        messages.removeAll { $0.id == pending.localMessageID }
        publishLocalOutboxState()
        attachmentUploadFailed = false
        statusMessage = "Media upload canceled."
        errorMessage = nil
        Task {
            await sendInputActivity(.cancel, force: true)
        }
    }

    private func restoreComposer(from pending: HSPendingAttachmentUpload) {
        draft = pending.caption
        replyingToMessage = pending.replyMessage
        draftReplyToMessageID = pending.replyToMessageID
    }

    private func cancelActiveTransfersOnDisappear() {
        if let pending = pendingAttachmentUpload {
            restoreComposer(from: pending)
            mediaDownloadStates.removeValue(forKey: pending.localMessageID)
            messages.removeAll { $0.id == pending.localMessageID }
            publishLocalOutboxState()
        }
        attachmentUploadTask?.cancel()
        attachmentUploadTask = nil
        pendingAttachmentUpload = nil
        attachmentUploadFailed = false
        Task {
            await sendInputActivity(.cancel, force: true)
        }
        mediaDownloadTasks.values.forEach { $0.cancel() }
        mediaDownloadTasks.removeAll()
        mediaDownloadStates = mediaDownloadStates.filter { !$0.value.isDownloading }
    }

    private func handleTextEntity(_ action: MessageTextEntityAction) {
        switch action {
        case .url(let url):
            UIApplication.shared.open(url)
        case .mention(let mention):
            beginThreadSearch(query: "@\(mention)")
            statusMessage = "Searching @\(mention)"
        case .hashtag(let hashtag):
            beginThreadSearch(query: "#\(hashtag)")
            statusMessage = "Searching #\(hashtag)"
        }
        errorMessage = nil
    }

    private func beginSelection(_ message: HSMessage) {
        guard message.kind != "service", isServerBackedMessage(message) else {
            return
        }
        endThreadSearch()
        selectedMessageIDs = [message.id]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleSelection(_ message: HSMessage) {
        guard message.kind != "service", isServerBackedMessage(message) else {
            return
        }
        if selectedMessageIDs.contains(message.id) {
            selectedMessageIDs.remove(message.id)
        } else {
            selectedMessageIDs.insert(message.id)
        }
    }

    private func clearSelection() {
        selectedMessageIDs.removeAll()
        isShowingSelectionForwardSheet = false
        isShowingSelectionDeleteConfirmation = false
    }

    private func confirmHistoryAction(_ action: PrivateChatHistoryAction) {
        guard canManagePrivateChatHistory else {
            return
        }
        pendingHistoryAction = action
    }

    private func applyCustomMuteHours() {
        guard let hours = Int(customMuteHoursText.trimmingCharacters(in: .whitespacesAndNewlines)), hours > 0 else {
            statusMessage = nil
            errorMessage = "Enter a valid mute duration."
            return
        }
        let interval = min(hours, Int(Int32.max / 3600)) * 3600
        Task {
            await updatePeerMute(interval: interval)
        }
    }

    private func updatePeerMute(interval: Int) async {
        guard let session = authStore.session, canManagePrivateChatHistory else {
            return
        }
        do {
            _ = try await authStore.api.updatePeerNotificationSettings(
                dialogID: chat.id,
                muteInterval: interval,
                session: session
            )
            isPeerMuted = interval != 0
            statusMessage = peerMuteStatusText(interval: interval)
            errorMessage = nil
            NotificationCenter.default.post(
                name: .hsNativeSyncDidChange,
                object: nil,
                userInfo: ["dialog_ids": [chat.id]]
            )
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func peerMuteStatusText(interval: Int) -> String {
        if interval == 0 {
            return "Notifications enabled."
        }
        if interval >= Self.muteForeverInterval {
            return "Muted forever."
        }
        if interval >= 24 * 60 * 60, interval % (24 * 60 * 60) == 0 {
            return "Muted for \(interval / (24 * 60 * 60)) days."
        }
        if interval >= 60 * 60, interval % (60 * 60) == 0 {
            return "Muted for \(interval / (60 * 60)) hours."
        }
        return "Muted."
    }

    private func applyHistoryAction(_ action: PrivateChatHistoryAction) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteDialogHistory(
                dialogID: chat.id,
                justClear: action.justClear,
                revoke: action.revoke,
                maxMessageID: historyMaxMessageID,
                session: session
            )
            clearSelection()
            cancelLocalTransfersAfterHistoryRemoval()
            messages.removeAll()
            hasMoreHistory = false
            unreadSeparatorMessageID = nil
            shouldScrollToUnreadSeparator = false
            postLocalOutboxClear()
            NotificationCenter.default.post(
                name: .hsNativeSyncDidChange,
                object: nil,
                userInfo: ["dialog_ids": [chat.id]]
            )
            statusMessage = action.successMessage
            errorMessage = nil
            if action.dismissesThread {
                draft = ""
                replyingToMessage = nil
                draftReplyToMessageID = nil
                clearLinkPreviewState()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var historyMaxMessageID: Int64? {
        chat.topMessageID ?? messages.map(\.id).filter { $0 > 0 }.max()
    }

    private func cancelLocalTransfersAfterHistoryRemoval() {
        attachmentUploadTask?.cancel()
        attachmentUploadTask = nil
        pendingAttachmentUpload = nil
        attachmentUploadFailed = false
        mediaDownloadTasks.values.forEach { $0.cancel() }
        mediaDownloadTasks.removeAll()
        mediaDownloadStates.removeAll()
        downloadedMediaURLs.removeAll()
    }

    private func isServerBackedMessage(_ message: HSMessage) -> Bool {
        guard message.id > 0 else {
            return false
        }
        switch message.deliveryState {
        case .sent, .read:
            return true
        case .sending, .failed:
            return false
        }
    }

    private func copySelectedMessages() {
        let copiedText = selectedMessages
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !copiedText.isEmpty else {
            return
        }
        UIPasteboard.general.string = copiedText
        statusMessage = selectedMessageIDs.count == 1 ? "Message copied." : "\(selectedMessageIDs.count) messages copied."
        errorMessage = nil
        clearSelection()
    }

    private func forwardSelectedMessages(to target: HSChat) async {
        guard let session = authStore.session else {
            return
        }
        let selected = selectedMessages
        guard !selected.isEmpty else {
            return
        }
        do {
            for message in selected {
                _ = try await authStore.api.forwardMessage(dialogID: chat.id, messageID: message.id, toDialogID: target.id, session: session)
            }
            statusMessage = selected.count == 1 ? "Forwarded to \(target.title)." : "\(selected.count) messages forwarded to \(target.title)."
            errorMessage = nil
            clearSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedMessages() async {
        guard let session = authStore.session else {
            return
        }
        let selectedIDs = selectedMessageIDs
        guard !selectedIDs.isEmpty else {
            return
        }
        var deletedIDs = Set<Int64>()
        do {
            for messageID in selectedIDs.sorted() {
                _ = try await authStore.api.deleteMessage(dialogID: chat.id, messageID: messageID, session: session)
                deletedIDs.insert(messageID)
            }
            messages.removeAll { deletedIDs.contains($0.id) }
            statusMessage = deletedIDs.count == 1 ? "Message deleted." : "\(deletedIDs.count) messages deleted."
            errorMessage = nil
            clearSelection()
        } catch {
            messages.removeAll { deletedIDs.contains($0.id) }
            selectedMessageIDs.subtract(deletedIDs)
            errorMessage = error.localizedDescription
        }
    }

    private func markRead(messages: [HSMessage]) async {
        guard let session = authStore.session,
              let last = messages.last(where: { $0.id > 0 }) else {
            return
        }
        _ = try? await authStore.api.markDialogRead(dialogID: chat.id, maxMessageID: last.id, session: session)
        if chat.isMarkedUnread {
            _ = try? await authStore.api.markDialogUnread(dialogID: chat.id, unread: false, session: session)
        }
    }

    private func loadInitialMessages(session: HSUserSession) async throws -> (messages: [HSMessage], hasMoreHistory: Bool) {
        var loaded = try await authStore.api.messages(dialogID: chat.id, limit: pageSize, session: session)
        var canLoadEarlier = loaded.count >= pageSize

        guard chat.unreadCount > 0 else {
            return (loaded, canLoadEarlier)
        }

        var loadedIDs = Set(loaded.map(\.id))
        while loaded.filter({ !$0.isOutgoing }).count < chat.unreadCount,
              canLoadEarlier,
              loaded.count < pageSize * 5,
              let oldest = loaded.first {
            let olderPage = try await authStore.api.messages(dialogID: chat.id, beforeID: oldest.id, limit: pageSize, session: session)
            canLoadEarlier = olderPage.count >= pageSize
            let uniqueOlderMessages = olderPage.filter { loadedIDs.insert($0.id).inserted }
            guard !uniqueOlderMessages.isEmpty else {
                break
            }
            loaded.insert(contentsOf: uniqueOlderMessages, at: 0)
        }

        return (loaded, canLoadEarlier)
    }

    private func initialUnreadSeparatorMessageID(in loadedMessages: [HSMessage]) -> Int64? {
        guard chat.unreadCount > 0 else {
            return nil
        }
        let incomingMessages = loadedMessages.filter { !$0.isOutgoing }
        guard incomingMessages.count >= chat.unreadCount else {
            return nil
        }
        let firstUnreadOffset = max(0, incomingMessages.count - chat.unreadCount)
        return incomingMessages[firstUnreadOffset].id
    }

    private func shouldShowDateSeparator(for message: HSMessage, after previousMessage: HSMessage?) -> Bool {
        guard message.sentAt.timeIntervalSince1970 >= 10 else {
            return false
        }
        guard let previousMessage else {
            return true
        }
        return !Calendar.current.isDate(message.sentAt, inSameDayAs: previousMessage.sentAt)
    }

    private func canMerge(_ message: HSMessage, withPrevious previousMessage: HSMessage?) -> Bool {
        guard let previousMessage else {
            return false
        }
        return canMerge(previousMessage, withNext: message)
    }

    private func canMerge(_ message: HSMessage, withNext nextMessage: HSMessage?) -> Bool {
        guard let nextMessage,
              message.kind != "service",
              nextMessage.kind != "service",
              message.dialogID == nextMessage.dialogID,
              message.authorID == nextMessage.authorID,
              message.isOutgoing == nextMessage.isOutgoing,
              message.authorSignature == nextMessage.authorSignature,
              Calendar.current.isDate(message.sentAt, inSameDayAs: nextMessage.sentAt),
              abs(message.sentAt.timeIntervalSince(nextMessage.sentAt)) < 10 * 60 else {
            return false
        }
        return true
    }

    private func beginEdit(_ message: HSMessage) {
        guard isServerBackedMessage(message) else {
            return
        }
        editingMessage = message
        editText = message.text
    }

    private func beginReply(_ message: HSMessage) {
        guard isServerBackedMessage(message) else {
            return
        }
        replyingToMessage = message
        draftReplyToMessageID = message.id
    }

    private func clearReply() {
        replyingToMessage = nil
        draftReplyToMessageID = nil
    }

    private func restoreDraftReplyTarget() {
        guard let replyID = draftReplyToMessageID else {
            return
        }
        replyingToMessage = messages.first { $0.id == replyID }
    }

    private func saveEdit() async {
        guard let session = authStore.session, let message = editingMessage else {
            return
        }
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        do {
            let edited = try await authStore.api.editMessage(dialogID: chat.id, messageID: message.id, text: text, session: session)
            replace(messageID: message.id, with: edited)
            editingMessage = nil
            editText = ""
            statusMessage = "Message updated."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ message: HSMessage) async {
        guard isServerBackedMessage(message) else {
            if pendingAttachmentUpload?.localMessageID == message.id {
                attachmentUploadTask?.cancel()
                attachmentUploadTask = nil
                pendingAttachmentUpload = nil
                attachmentUploadFailed = false
            }
            mediaDownloadStates.removeValue(forKey: message.id)
            messages.removeAll { $0.id == message.id }
            selectedMessageIDs.remove(message.id)
            statusMessage = "Message removed."
            errorMessage = nil
            return
        }
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteMessage(dialogID: chat.id, messageID: message.id, session: session)
            messages.removeAll { $0.id == message.id }
            statusMessage = "Message deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func forward(_ message: HSMessage, to target: HSChat) async {
        guard isServerBackedMessage(message) else {
            return
        }
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.forwardMessage(dialogID: chat.id, messageID: message.id, toDialogID: target.id, session: session)
            forwardingMessage = nil
            statusMessage = "Forwarded to \(target.title)."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func react(_ message: HSMessage, reaction: String) async {
        guard isServerBackedMessage(message) else {
            return
        }
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.sendReaction(dialogID: chat.id, messageID: message.id, reaction: reaction, session: session)
            replace(messageID: message.id, with: message.withUpdatedReaction(reaction))
            statusMessage = "Reaction sent."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pin(_ message: HSMessage) async {
        guard isServerBackedMessage(message) else {
            return
        }
        guard let session = authStore.session else {
            return
        }
        do {
            let serviceMessage = try await authStore.api.pinSupergroupMessage(dialogID: chat.id, messageID: message.id, session: session)
            shouldScrollToLatest = true
            messages.append(serviceMessage)
            statusMessage = "Message pinned."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyLink(_ message: HSMessage) async {
        guard isServerBackedMessage(message) else {
            return
        }
        guard let session = authStore.session else {
            return
        }
        do {
            let link = try await authStore.api.supergroupMessageLink(dialogID: chat.id, messageID: message.id, session: session)
            UIPasteboard.general.string = link.link
            statusMessage = "Message link copied."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(messageID: Int64, with message: HSMessage) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        messages[index] = message
        if message.isOutgoing {
            publishLocalOutboxState()
        }
    }
}

private struct ChatThreadMessageRow: Identifiable {
    let message: HSMessage
    let previousMessage: HSMessage?
    let isMergedWithPrevious: Bool
    let isMergedWithNext: Bool

    var id: Int64 {
        message.id
    }
}

private struct ChatComposerLinkPreviewBar: View {
    let preview: HSWebPagePreview?
    let isLoading: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            previewIcon
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HSTheme.primaryText)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(HSTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(HSTheme.secondaryText)
            .accessibilityLabel("Hide link preview")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HSTheme.Chat.composerBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(HSTheme.Chat.panelSeparatorColor)
                .frame(height: 1 / UIScreen.main.scale)
        }
    }

    private var previewIcon: some View {
        Group {
            if preview?.photo != nil {
                Image(systemName: "photo")
            } else if preview?.document != nil {
                Image(systemName: "doc.text")
            } else {
                Image(systemName: "link")
            }
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(HSTheme.accent)
    }

    private var title: String {
        if isLoading, preview == nil {
            return "Loading preview"
        }
        return firstNonEmpty(preview?.title, preview?.siteName, preview?.displayURL, preview?.url) ?? "Link preview"
    }

    private var subtitle: String? {
        if isLoading, preview == nil {
            return "Fetching link details"
        }
        return firstNonEmpty(preview?.description, preview?.displayURL, preview?.url, preview?.author)
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct MediaPreviewSheet: View {
    let item: HSMediaPreviewItem

    var body: some View {
        NavigationStack {
            previewContent
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ShareLink(item: item.url) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let image = item.image {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height * 0.72)
                    .padding()
            }
            .background(Color.black.opacity(0.94))
        } else if item.media.kind == .video {
            VideoPlayer(player: AVPlayer(url: item.url))
                .background(Color.black)
        } else if item.media.kind == .audio || item.media.kind == .voice {
            AudioPreviewView(url: item.url, title: title, metadataText: metadataText)
        } else {
            VStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(HSTheme.accent)
                    .frame(width: 76, height: 76)
                    .background(HSTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                if let metadataText {
                    Text(metadataText)
                        .font(.footnote)
                        .foregroundStyle(HSTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HSTheme.grouped)
        }
    }

    private var title: String {
        item.media.fileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? item.media.fileName!
            : fallbackTitle
    }

    private var fallbackTitle: String {
        switch item.media.kind {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .gif:
            return "GIF"
        case .audio:
            return "Audio"
        case .voice:
            return "Voice Message"
        case .sticker:
            return "Sticker"
        case .webpage:
            return "Link Preview"
        case .file:
            return "File"
        case .unknown:
            return "Media"
        }
    }

    private var iconName: String {
        switch item.media.kind {
        case .audio, .voice:
            return "waveform"
        case .file:
            return "doc.fill"
        case .sticker:
            return "face.smiling"
        case .photo:
            return "photo"
        case .video:
            return "play.rectangle.fill"
        case .gif:
            return "sparkles.rectangle.stack"
        case .webpage:
            return "link"
        case .unknown:
            return "paperclip"
        }
    }

    private var metadataText: String? {
        var parts: [String] = []
        if let mimeType = item.media.mimeType, !mimeType.isEmpty {
            parts.append(mimeType)
        }
        if let size = item.media.size, size > 0 {
            parts.append(Self.byteFormatter.string(fromByteCount: size))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter
    }()
}

private struct AudioPreviewView: View {
    let url: URL
    let title: String
    let metadataText: String?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackObserver: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(HSTheme.accent)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let metadataText {
                Text(metadataText)
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 54, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(HSTheme.accent)
            .accessibilityLabel(isPlaying ? "暂停播放" : "播放语音")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HSTheme.grouped)
        .onAppear {
            player = AVPlayer(url: url)
            playbackObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                player?.seek(to: .zero)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            isPlaying = false
            if let playbackObserver {
                NotificationCenter.default.removeObserver(playbackObserver)
                self.playbackObserver = nil
            }
        }
    }

    private func togglePlayback() {
        guard let player else {
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
}

private struct ChatDateSeparatorView: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(Self.title(for: date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HSTheme.Chat.servicePill, in: Capsule())
                .accessibilityLabel(Self.title(for: date))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private static func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return relativeDateFormatter.string(from: date)
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            return monthDayFormatter.string(from: date)
        }
        return fullDateFormatter.string(from: date)
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private static let relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("y MMM d")
        return formatter
    }()
}

private struct ChatUnreadSeparatorView: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(HSTheme.accent.opacity(0.24))
                .frame(height: 1)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HSTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HSTheme.accent.opacity(0.11), in: Capsule())
                .accessibilityLabel(title)

            Rectangle()
                .fill(HSTheme.accent.opacity(0.24))
                .frame(height: 1)
        }
        .frame(height: 25)
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
    }

    private var title: String {
        "未读消息"
    }
}

private struct ChatThreadNavigationTitle: View {
    let chat: HSChat
    let mode: HSChatThreadMode
    let inputActivity: HSInputActivity?

    var body: some View {
        HStack(spacing: 8) {
            HSClassicAvatar(title: chat.title, icon: iconName, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(chat.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HSTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(inputActivity == nil ? HSTheme.secondaryText : HSTheme.accent)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 220)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let inputActivity, let title = activityTitle(inputActivity) {
            return title
        }
        if case .savedMessages = mode {
            return "Saved Messages"
        }
        if chat.isCircle {
            return chat.subtitle.isEmpty ? "group" : chat.subtitle
        }
        return chat.subtitle.isEmpty ? "online" : chat.subtitle
    }

    private func activityTitle(_ activity: HSInputActivity) -> String? {
        switch activity.kind {
        case .cancel:
            return nil
        case .typing:
            return "typing..."
        case .recordingVoice:
            return "recording voice..."
        case .recordingVideo:
            return "recording video..."
        case .uploadingFile:
            return uploadTitle("uploading file", activity.progress)
        case .uploadingPhoto:
            return uploadTitle("uploading photo", activity.progress)
        case .uploadingVideo:
            return uploadTitle("uploading video", activity.progress)
        case .uploadingVoice:
            return uploadTitle("uploading voice", activity.progress)
        case .uploadingInstantVideo:
            return uploadTitle("uploading video message", activity.progress)
        case .choosingSticker:
            return "choosing sticker..."
        }
    }

    private func uploadTitle(_ title: String, _ progress: Int?) -> String {
        guard let progress else {
            return "\(title)..."
        }
        return "\(title) \(max(0, min(100, progress)))%"
    }

    private var iconName: String {
        if case .savedMessages = mode {
            return "bookmark.fill"
        }
        return chat.isCircle ? "person.3.fill" : "person.fill"
    }

    private var tint: Color {
        if case .savedMessages = mode {
            return HSTheme.trust
        }
        return chat.isCircle ? HSTheme.circle : HSTheme.accent
    }
}
