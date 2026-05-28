import Foundation
import SwiftUI

struct SharedMediaBrowserView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    let chat: HSChat
    let onSelect: (HSMessage) -> Void

    @State private var selectedFilter: HSSharedMediaFilter = .media
    @State private var messages: [HSMessage] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var activeReloadID = UUID()
    @State private var counters: [HSSharedMediaFilter: Int] = [:]

    private let pageSize = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SharedMediaFilterTabs(selectedFilter: $selectedFilter, counters: counters)

                content
            }
            .navigationTitle("共享媒体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await reloadAll()
            }
            .onChange(of: selectedFilter) { _ in
                Task {
                    await reload()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && messages.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在加载")
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HSTheme.Chat.listBackground)
        } else if selectedFilter.usesGrid {
            mediaGridContent
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            if let errorMessage {
                Section {
                    HSErrorBanner(message: errorMessage)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                if messages.isEmpty {
                    SharedMediaEmptyView(filter: selectedFilter)
                }

                ForEach(messages) { message in
                    SharedMediaBrowserRow(filter: selectedFilter, message: message) {
                        onSelect(message)
                        dismiss()
                    }
                }

                loadMoreButton
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(HSTheme.Chat.listBackground)
        .refreshable {
            await reloadAll()
        }
    }

    private var mediaGridContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }

                if messages.isEmpty {
                    SharedMediaEmptyView(filter: selectedFilter)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: mediaGridColumns, spacing: 2) {
                        ForEach(messages) { message in
                            SharedMediaGridTile(message: message) {
                                onSelect(message)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                }

                loadMoreButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(HSTheme.Chat.listBackground)
        .refreshable {
            await reloadAll()
        }
    }

    private var loadMoreButton: some View {
        Group {
            if hasMore && !messages.isEmpty {
                Button {
                    Task {
                        await loadMore()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoadingMore {
                            ProgressView()
                        } else {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        Text(isLoadingMore ? "加载中" : "加载更多")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingMore)
            }
        }
    }

    private var mediaGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 112, maximum: 164), spacing: 2)]
    }

    private func reload() async {
        let filter = selectedFilter
        let reloadID = UUID()
        activeReloadID = reloadID
        isLoading = true
        isLoadingMore = false
        hasMore = true
        errorMessage = nil
        defer {
            if activeReloadID == reloadID {
                isLoading = false
            }
        }

        do {
            let loaded = try await fetch(filter: filter, offsetID: nil)
            guard activeReloadID == reloadID, filter == selectedFilter else {
                return
            }
            messages = loaded
            hasMore = loaded.count >= pageSize
        } catch {
            guard activeReloadID == reloadID, filter == selectedFilter else {
                return
            }
            messages = []
            hasMore = false
            errorMessage = error.localizedDescription
        }
    }

    private func reloadAll() async {
        await refreshCounters()
        await reload()
    }

    private func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMore, let last = messages.last else {
            return
        }
        let filter = selectedFilter
        isLoadingMore = true
        errorMessage = nil
        defer {
            isLoadingMore = false
        }

        do {
            let loaded = try await fetch(filter: filter, offsetID: last.id)
            guard filter == selectedFilter else {
                return
            }
            let existingIDs = Set(messages.map(\.id))
            let more = loaded.filter { !existingIDs.contains($0.id) }
            messages.append(contentsOf: more)
            hasMore = loaded.count >= pageSize && !more.isEmpty
        } catch {
            guard filter == selectedFilter else {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func refreshCounters() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let loaded = try await authStore.api.sharedMediaCounters(
                dialogID: chat.id,
                filters: HSSharedMediaFilter.allCases,
                session: session
            )
            counters = Dictionary(uniqueKeysWithValues: loaded.map { ($0.filter, $0.count) })
        } catch {
            counters = [:]
        }
    }

    private func fetch(filter: HSSharedMediaFilter, offsetID: Int64?) async throws -> [HSMessage] {
        guard let session = authStore.session else {
            throw HSAPIError.missingSession
        }
        return try await authStore.api.sharedMedia(
            dialogID: chat.id,
            filter: filter,
            offsetID: offsetID,
            limit: pageSize,
            session: session
        )
    }
}

private struct SharedMediaFilterTabs: View {
    @Binding var selectedFilter: HSSharedMediaFilter
    let counters: [HSSharedMediaFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HSSharedMediaFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.tabIconName)
                                .font(.system(size: 13, weight: .semibold))
                            Text(filter.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            if let count = counters[filter] {
                                Text(Self.countText(count))
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(
                                        selectedFilter == filter ? Color.white.opacity(0.24) : HSTheme.accent.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                        }
                        .foregroundStyle(selectedFilter == filter ? .white : HSTheme.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            selectedFilter == filter ? HSTheme.accent : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityTitle(for: filter))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func accessibilityTitle(for filter: HSSharedMediaFilter) -> String {
        guard let count = counters[filter] else {
            return filter.title
        }
        return "\(filter.title)，\(count) 项"
    }

    private static func countText(_ count: Int) -> String {
        if count >= 10_000 {
            return "\(count / 1_000)K"
        }
        return "\(count)"
    }
}

private struct SharedMediaBrowserRow: View {
    @Environment(\.openURL) private var openURL

    let filter: HSSharedMediaFilter
    let message: HSMessage
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HSTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Text(message.sentAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(HSTheme.secondaryText)
                        .lineLimit(1)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(HSTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(HSTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            if let url = firstURL {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开链接")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var title: String {
        if filter == .links {
            if let previewTitle = message.media?.webPage?.title, !previewTitle.isEmpty {
                return previewTitle
            }
            if let siteName = message.media?.webPage?.siteName, !siteName.isEmpty {
                return siteName
            }
            if let host = firstURL?.host, !host.isEmpty {
                return host
            }
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "链接消息" : text
        }

        guard let media = message.media else {
            return message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? filter.title : message.text
        }
        if let fileName = media.fileName, !fileName.isEmpty {
            return fileName
        }
        return media.kind.title
    }

    private var subtitle: String? {
        if filter == .links {
            if let description = message.media?.webPage?.description, !description.isEmpty {
                return description
            }
            if let url = firstURL {
                return url.absoluteString
            }
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        let caption = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty, caption != title {
            return caption
        }
        return message.authorName.isEmpty ? nil : message.authorName
    }

    private var metadataText: String? {
        guard let media = message.media else {
            return filter == .links ? message.authorName : nil
        }
        var parts: [String] = []
        if let mimeType = media.mimeType, !mimeType.isEmpty {
            parts.append(mimeType)
        }
        if let size = media.size, size > 0 {
            parts.append(Self.byteFormatter.string(fromByteCount: size))
        }
        if let width = media.width, let height = media.height, width > 0, height > 0 {
            parts.append("\(width)x\(height)")
        }
        if let duration = media.duration, duration > 0 {
            parts.append(Self.durationFormatter.string(from: duration) ?? "\(Int(duration))s")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var firstURL: URL? {
        Self.firstURL(from: message.media?.webPage?.url)
            ?? Self.firstURL(from: message.media?.webPage?.displayURL)
            ?? Self.firstURL(in: message.text)
    }

    private var iconName: String {
        if filter == .links {
            return "link"
        }
        switch message.media?.kind {
        case .photo:
            return "photo"
        case .video:
            return "play.rectangle.fill"
        case .gif:
            return "sparkles.rectangle.stack"
        case .audio:
            return "waveform"
        case .voice:
            return "mic.fill"
        case .sticker:
            return "face.smiling"
        case .webpage:
            return "link"
        case .file:
            return "doc.fill"
        case .unknown, nil:
            return filter == .files ? "doc.fill" : "paperclip"
        }
    }

    private var iconColor: Color {
        if filter == .links {
            return HSTheme.accent
        }
        switch message.media?.kind {
        case .photo:
            return HSTheme.accent
        case .video:
            return .red
        case .gif:
            return .purple
        case .audio:
            return .green
        case .voice:
            return .green
        case .sticker:
            return .orange
        case .webpage:
            return HSTheme.accent
        case .file:
            return .indigo
        case .unknown, nil:
            return HSTheme.secondaryText
        }
    }

    private static func firstURL(in text: String) -> URL? {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return linkDetector?.firstMatch(in: text, options: [], range: range)?.url
    }

    private static func firstURL(from value: String?) -> URL? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

private struct SharedMediaGridTile: View {
    let message: HSMessage
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Rectangle()
                    .fill(backgroundColor)

                VStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 50, height: 50)
                        .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if media?.kind == .voice {
                        SharedMediaMiniWaveform(samples: HSVoiceWaveformCodec.decode(media?.waveform, fallbackCount: 18), tint: iconColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Spacer()
                    HStack(spacing: 5) {
                        if isPlayable {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(detailText)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .background(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.36))
                        .frame(height: 48)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .accessibilityLabel(accessibilityLabel)
        }
        .buttonStyle(.plain)
    }

    private var media: HSMessageMedia? {
        message.media
    }

    private var title: String {
        if let fileName = media?.fileName, !fileName.isEmpty {
            return fileName
        }
        let caption = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            return caption
        }
        return media?.kind.title ?? "Media"
    }

    private var detailText: String {
        var parts: [String] = []
        if let duration = media?.duration, duration > 0 {
            parts.append(Self.durationFormatter.string(from: duration) ?? "\(Int(duration))s")
        } else if let size = media?.size, size > 0 {
            parts.append(Self.byteFormatter.string(fromByteCount: size))
        }
        parts.append(Self.dateFormatter.string(from: message.sentAt))
        return parts.joined(separator: " · ")
    }

    private var iconName: String {
        switch media?.kind {
        case .photo:
            return "photo.fill"
        case .video:
            return "play.rectangle.fill"
        case .gif:
            return "sparkles.rectangle.stack.fill"
        case .audio:
            return "waveform"
        case .voice:
            return "mic.fill"
        case .sticker:
            return "face.smiling.fill"
        case .webpage:
            return "link"
        case .file:
            return "doc.fill"
        case .unknown, nil:
            return "paperclip"
        }
    }

    private var iconColor: Color {
        switch media?.kind {
        case .photo:
            return HSTheme.accent
        case .video:
            return .red
        case .gif:
            return .purple
        case .audio, .voice:
            return .green
        case .sticker:
            return .orange
        case .webpage:
            return HSTheme.accent
        case .file:
            return .indigo
        case .unknown, nil:
            return HSTheme.secondaryText
        }
    }

    private var backgroundColor: Color {
        switch media?.kind {
        case .photo:
            return HSTheme.accent.opacity(0.10)
        case .video:
            return Color.red.opacity(0.10)
        case .gif:
            return Color.purple.opacity(0.10)
        case .audio, .voice:
            return Color.green.opacity(0.10)
        case .sticker:
            return Color.orange.opacity(0.12)
        case .webpage:
            return HSTheme.accent.opacity(0.10)
        case .file:
            return Color.indigo.opacity(0.10)
        case .unknown, nil:
            return Color(.secondarySystemGroupedBackground)
        }
    }

    private var isPlayable: Bool {
        media?.kind == .video || media?.kind == .gif || media?.kind == .audio || media?.kind == .voice
    }

    private var accessibilityLabel: String {
        "\(media?.kind.title ?? "Media"), \(detailText)"
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct SharedMediaMiniWaveform: View {
    let samples: [Double]
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(samples.prefix(18).enumerated()), id: \.offset) { _, sample in
                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 3, height: 5 + CGFloat(min(1, max(0.08, sample))) * 15)
            }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

private struct SharedMediaEmptyView: View {
    let filter: HSSharedMediaFilter

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.emptyIconName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HSTheme.secondaryText)
            Text(filter.emptyTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HSTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private extension HSSharedMediaFilter {
    var usesGrid: Bool {
        switch self {
        case .media, .gifs:
            return true
        case .files, .links, .voice, .music:
            return false
        }
    }

    var title: String {
        switch self {
        case .media:
            return "媒体"
        case .files:
            return "文件"
        case .links:
            return "链接"
        case .gifs:
            return "GIF"
        case .voice:
            return "语音"
        case .music:
            return "音乐"
        }
    }

    var emptyTitle: String {
        switch self {
        case .media:
            return "没有媒体"
        case .files:
            return "没有文件"
        case .links:
            return "没有链接"
        case .gifs:
            return "没有 GIF"
        case .voice:
            return "没有语音消息"
        case .music:
            return "没有音乐"
        }
    }

    var emptyIconName: String {
        switch self {
        case .media:
            return "photo.on.rectangle"
        case .files:
            return "doc"
        case .links:
            return "link"
        case .gifs:
            return "sparkles.rectangle.stack"
        case .voice:
            return "mic"
        case .music:
            return "music.note"
        }
    }

    var tabIconName: String {
        switch self {
        case .media:
            return "photo.on.rectangle"
        case .files:
            return "doc"
        case .links:
            return "link"
        case .gifs:
            return "sparkles.rectangle.stack"
        case .voice:
            return "mic"
        case .music:
            return "music.note"
        }
    }
}

private extension HSMessageMedia.MediaKind {
    var title: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .file:
            return "File"
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
        case .unknown:
            return "Media"
        }
    }
}
