import SwiftUI
import UIKit

enum MessageTextEntityAction: Equatable {
    case url(URL)
    case mention(String)
    case hashtag(String)
}

enum HSMediaDownloadState: Equatable {
    case downloading(progress: Double?)
    case downloaded
    case failed

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    var progress: Double? {
        if case .downloading(let progress) = self {
            return progress
        }
        return nil
    }
}

struct MessageBubble: View {
    let message: HSMessage
    let replyPreview: HSMessage?
    let isGroup: Bool
    let showsAvatar: Bool
    let isMergedWithPrevious: Bool
    let isMergedWithNext: Bool
    let isHighlighted: Bool
    let isSelecting: Bool
    let isSelected: Bool
    let onReply: () -> Void
    let onOpenReply: (Int64) -> Void
    let onToggleSelection: () -> Void
    let onBeginSelection: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onForward: () -> Void
    let onReact: (String) -> Void
    let onPin: () -> Void
    let onCopyLink: () -> Void
    let onRetry: () -> Void
    let onOpenTextEntity: (MessageTextEntityAction) -> Void
    let mediaDownloadState: HSMediaDownloadState?
    let onOpenMedia: () -> Void

    @GestureState private var swipeOffset: CGFloat = 0

    var body: some View {
        Group {
            if message.kind == "service" {
                serviceMessageBody
            } else {
                bubbleMessageBody
            }
        }
        .overlay(alignment: message.isOutgoing ? .trailing : .leading) {
            if swipeOffset < -8 {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HSTheme.accent)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.85), in: Circle())
                    .offset(x: message.isOutgoing ? 32 : -32)
            }
        }
        .offset(x: swipeOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .updating($swipeOffset) { value, state, _ in
                    guard !isSelecting, canUseServerActions else {
                        return
                    }
                    guard value.translation.width < 0, abs(value.translation.height) < 32 else {
                        return
                    }
                    state = max(value.translation.width / 3, -28)
                }
                .onEnded { value in
                    guard !isSelecting, canUseServerActions else {
                        return
                    }
                    guard value.translation.width < -64, abs(value.translation.height) < 40 else {
                        return
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReply()
                }
        )
    }

    private var bubbleMessageBody: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isSelecting && isSelectable {
                selectionButton
            }

            if message.isOutgoing {
                Spacer(minLength: 52)
            } else if reservesIncomingAvatarColumn {
                incomingAvatarColumn
            }

            bubbleContent
                .padding(.top, isMergedWithPrevious ? -2 : 0)
                .padding(.bottom, isMergedWithNext ? -2 : 0)

            if !message.isOutgoing {
                Spacer(minLength: 52)
            }
        }
    }

    private var reservesIncomingAvatarColumn: Bool {
        !message.isOutgoing && isGroup
    }

    private var incomingAvatarColumn: some View {
        Group {
            if showsAvatar {
                HSClassicAvatar(
                    title: message.authorName,
                    icon: "person.fill",
                    tint: avatarTint,
                    size: 30
                )
            } else {
                Color.clear
            }
        }
        .frame(width: 30, height: 30)
    }

    private var serviceMessageBody: some View {
        HStack {
            Spacer()
            Text(message.text.isEmpty ? "Service update" : message.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HSTheme.Chat.servicePill, in: Capsule())
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var selectionButton: some View {
        Button {
            onToggleSelection()
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? HSTheme.accent : .secondary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Deselect message" : "Select message")
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isMergedWithPrevious, let authorHeaderText {
                Text(authorHeaderText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HSTheme.accent)
                    .lineLimit(1)
            }

            if let replyToMessageID = message.replyToMessageID {
                Button {
                    onOpenReply(replyToMessageID)
                } label: {
                    ReplyReferenceView(
                        messageID: replyToMessageID,
                        preview: replyPreview,
                        isOutgoing: message.isOutgoing
                    )
                }
                .buttonStyle(.plain)
            }

            if message.kind == "media" {
                MediaMessageCard(
                    media: message.media,
                    caption: message.text,
                    isOutgoing: message.isOutgoing,
                    deliveryState: message.deliveryState,
                    downloadState: mediaDownloadState,
                    onOpenMedia: onOpenMedia
                )
            } else {
                LinkedMessageTextView(
                    text: message.text,
                    isOutgoing: message.isOutgoing,
                    isInteractionEnabled: !isSelecting,
                    onOpen: onOpenTextEntity
                )
                .frame(maxWidth: min(UIScreen.main.bounds.width * 0.72, 520), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 4) {
                if message.counters.replyCount > 0 {
                    MessageMetricLabel(systemImage: "bubble.left.fill", value: message.counters.replyCount)
                }
                if let viewCount = message.counters.viewCount, viewCount > 0 {
                    MessageMetricLabel(systemImage: "eye.fill", value: viewCount)
                }
                Spacer(minLength: 16)
                Text(statusTimestampText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(message.isOutgoing ? HSTheme.Chat.outgoingSecondary : HSTheme.secondaryText)
                if message.isOutgoing {
                    MessageDeliveryStatusView(state: message.deliveryState)
                }
            }

            if !message.reactions.isEmpty {
                MessageReactionStrip(reactions: message.reactions, isOutgoing: message.isOutgoing) { reaction in
                    onReact(reaction.value)
                }
            }
        }
        .padding(.leading, message.isOutgoing ? 12 : 16)
        .padding(.trailing, message.isOutgoing ? 16 : 12)
        .padding(.vertical, 8)
        .background(message.isOutgoing ? HSTheme.Chat.outgoingBubble : HSTheme.Chat.incomingBubble, in: bubbleShape)
        .overlay {
            bubbleShape
                .stroke(isHighlighted || isSelected ? selectionStrokeColor : Color.black.opacity(0.08), lineWidth: isHighlighted || isSelected ? 2 : 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
        .foregroundStyle(HSTheme.primaryText)
        .onTapGesture {
            if isSelecting && isSelectable {
                onToggleSelection()
            }
        }
        .onLongPressGesture {
            if isSelectable {
                onBeginSelection()
            }
        }
        .contextMenu {
            messageContextMenu
        }
    }

    @ViewBuilder
    private var messageContextMenu: some View {
        Button {
            UIPasteboard.general.string = message.text
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }

        if isSelectable {
            Button {
                onBeginSelection()
            } label: {
                Label("选择", systemImage: "checkmark.circle")
            }
        }

        if message.isOutgoing && message.deliveryState == .failed {
            Button {
                onRetry()
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
            }
        }

        if canUseServerActions {
            Button {
                onReply()
            } label: {
                Label("回复", systemImage: "arrowshape.turn.up.left")
            }

            Button {
                onReact("👍")
            } label: {
                Label("回应", systemImage: "hand.thumbsup")
            }

            Button {
                onForward()
            } label: {
                Label("转发", systemImage: "arrowshape.turn.up.right")
            }

            if message.isOutgoing {
                Button {
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }

            if isGroup {
                Button {
                    onPin()
                } label: {
                    Label("置顶", systemImage: "pin")
                }
                Button {
                    onCopyLink()
                } label: {
                    Label("复制链接", systemImage: "link")
                }
            }
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var isSelectable: Bool {
        message.kind != "service" && canUseServerActions
    }

    private var bubbleShape: HSChatBubbleShape {
        HSChatBubbleShape(
            isOutgoing: message.isOutgoing,
            isMergedWithPrevious: isMergedWithPrevious,
            isMergedWithNext: isMergedWithNext
        )
    }

    private var authorHeaderText: String? {
        if let signature = message.authorSignature?.trimmingCharacters(in: .whitespacesAndNewlines), !signature.isEmpty {
            return signature
        }
        if !message.isOutgoing && isGroup {
            return message.authorName
        }
        return nil
    }

    private var avatarTint: Color {
        let colors = [
            HSTheme.accent,
            HSTheme.circle,
            HSTheme.trust,
            Color(rgb: 0xaf52de),
            Color(rgb: 0xff3b30),
            Color(rgb: 0x5856d6)
        ]
        return colors[Int(UInt64(bitPattern: message.authorID) % UInt64(colors.count))]
    }

    private var statusTimestampText: String {
        let time = Self.timeFormatter.string(from: message.sentAt)
        guard message.editDate != nil else {
            return time
        }
        return "edited \(time)"
    }

    private var canUseServerActions: Bool {
        switch message.deliveryState {
        case .sending, .failed:
            return false
        case .sent, .read:
            return true
        }
    }

    private var selectionStrokeColor: Color {
        if isSelected {
            return HSTheme.accent
        }
        if isHighlighted {
            return HSTheme.circle
        }
        return .clear
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct MessageDeliveryStatusView: View {
    let state: HSMessage.DeliveryState

    var body: some View {
        Group {
            switch state {
            case .sending:
                ProgressView()
                    .controlSize(.small)
                    .tint(HSTheme.Chat.outgoingSecondary)
                    .frame(width: 13, height: 13)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .frame(width: 14, height: 12)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HSTheme.Chat.outgoingSecondary)
                    .frame(width: 12, height: 12)
            case .read:
                DoubleCheckmarkView(color: HSTheme.Chat.outgoingSecondary)
                    .frame(width: 17, height: 12)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch state {
        case .sending:
            return "Sending"
        case .sent:
            return "Sent"
        case .read:
            return "Read"
        case .failed:
            return "Failed to send"
        }
    }
}

private struct DoubleCheckmarkView: View {
    let color: Color

    var body: some View {
        ZStack {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .offset(x: -2)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .offset(x: 3)
        }
        .foregroundStyle(color)
    }
}

private struct MessageMetricLabel: View {
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
            Text(Self.format(value))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(HSTheme.secondaryText)
        .accessibilityLabel("\(value)")
    }

    private static func format(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        }
        if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
    }
}

private struct MessageReactionStrip: View {
    let reactions: [HSMessageReaction]
    let isOutgoing: Bool
    let onSelect: (HSMessageReaction) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(visibleReactions) { reaction in
                Button {
                    onSelect(reaction)
                } label: {
                    HStack(spacing: 3) {
                        Text(displayValue(for: reaction))
                            .font(.system(size: 14))
                            .lineLimit(1)
                        if reaction.count > 1 {
                            Text("\(reaction.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(reaction.isSelected ? Color.white : reactionTextColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(reactionBackground(for: reaction), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(reactionBorderColor(for: reaction), lineWidth: 0.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(displayValue(for: reaction)) \(reaction.count)")
            }
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width * 0.72, 520), alignment: .leading)
        .padding(.top, 1)
    }

    private var visibleReactions: [HSMessageReaction] {
        reactions
            .filter { $0.count > 0 && !$0.value.isEmpty }
            .sorted { lhs, rhs in
                switch (lhs.chosenOrder, rhs.chosenOrder) {
                case let (left?, right?) where left != right:
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    if lhs.count != rhs.count {
                        return lhs.count > rhs.count
                    }
                    return lhs.value < rhs.value
                }
            }
            .prefix(6)
            .map { $0 }
    }

    private var reactionTextColor: Color {
        isOutgoing ? HSTheme.Chat.outgoingSecondary : HSTheme.primaryText
    }

    private func reactionBackground(for reaction: HSMessageReaction) -> Color {
        if reaction.isSelected {
            return HSTheme.accent
        }
        return isOutgoing ? Color.white.opacity(0.16) : HSTheme.accent.opacity(0.1)
    }

    private func reactionBorderColor(for reaction: HSMessageReaction) -> Color {
        if reaction.isSelected {
            return HSTheme.accent.opacity(0.85)
        }
        return isOutgoing ? Color.white.opacity(0.2) : HSTheme.accent.opacity(0.18)
    }

    private func displayValue(for reaction: HSMessageReaction) -> String {
        if reaction.value.hasPrefix("custom:") {
            return "✨"
        }
        return reaction.value
    }
}

private struct MediaMessageCard: View {
    @Environment(\.openURL) private var openURL

    let media: HSMessageMedia?
    let caption: String
    let isOutgoing: Bool
    let deliveryState: HSMessage.DeliveryState
    let downloadState: HSMediaDownloadState?
    let onOpenMedia: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let preview = media?.webPage {
                WebPagePreviewCard(preview: preview, tint: iconColor, secondaryColor: secondaryColor) {
                    openWebPage()
                }
            } else {
                mediaHeader
            }

            if media?.kind == .voice {
                VoiceMessageWaveformView(
                    samples: HSVoiceWaveformCodec.decode(media?.waveform),
                    tint: iconColor,
                    track: secondaryColor.opacity(isOutgoing ? 0.34 : 0.24)
                )
            }

            if let transferStatusText {
                HStack(spacing: 8) {
                    if downloadState?.isDownloading == true, let progress = downloadState?.progress {
                        ProgressView(value: progress)
                            .frame(maxWidth: 96)
                    } else if downloadState?.isDownloading == true {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(transferStatusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(transferStatusColor)
                        .lineLimit(1)
                }
            }

            if let captionText {
                Text(captionText)
                    .font(.body)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width * 0.72, 420), alignment: .leading)
    }

    private var mediaHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 38, height: 38)
                .background(iconColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let metadataText {
                    Text(metadataText)
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if canOpenMedia {
                Button(action: openMediaAction) {
                    actionIcon
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionAccessibilityLabel)
            }
        }
    }

    private func openMediaAction() {
        if media?.kind == .webpage {
            openWebPage()
        } else {
            onOpenMedia()
        }
    }

    private func openWebPage() {
        guard let url = webPageURL else {
            return
        }
        openURL(url)
    }

    @ViewBuilder
    private var actionIcon: some View {
        Image(systemName: actionIconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(actionIconColor)
            .frame(width: 32, height: 32)
            .background(actionIconColor.opacity(0.12), in: Circle())
    }

    private var title: String {
        guard let media else {
            return trimmedCaption.isEmpty ? "Media" : trimmedCaption
        }
        if let fileName = media.fileName, !fileName.isEmpty {
            return fileName
        }
        switch media.kind {
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
            return media.webPage?.title
                ?? media.webPage?.siteName
                ?? media.webPage?.displayURL
                ?? media.webPage?.url
                ?? "Link Preview"
        case .file:
            return "File"
        case .unknown:
            return "Media"
        }
    }

    private var captionText: String? {
        guard !trimmedCaption.isEmpty, trimmedCaption != title else {
            return nil
        }
        return trimmedCaption
    }

    private var metadataText: String? {
        guard let media else {
            return nil
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

    private var iconName: String {
        switch media?.kind {
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
        case .audio:
            return .green
        case .voice:
            return .green
        case .sticker:
            return .orange
        case .webpage:
            return HSTheme.accent
        case .file:
            return .blue
        case .unknown, nil:
            return HSTheme.secondaryText
        }
    }

    private var canOpenMedia: Bool {
        if isOutgoing {
            switch deliveryState {
            case .sending, .failed:
                return true
            case .sent, .read:
                break
            }
        }
        if media?.kind == .webpage {
            return webPageURL != nil
        }
        return media?.location != nil || downloadState == .downloaded
    }

    private var actionIconName: String {
        if isOutgoing {
            switch deliveryState {
            case .sending:
                return "xmark.circle.fill"
            case .failed:
                return "arrow.clockwise"
            case .sent, .read:
                break
            }
        }
        switch downloadState {
        case .downloaded:
            if media?.kind == .webpage {
                return "safari.fill"
            }
            if media?.kind == .photo || media?.kind == .gif {
                return "eye.fill"
            }
            if media?.kind == .audio || media?.kind == .voice {
                return "play.circle.fill"
            }
            return "square.and.arrow.up"
        case .failed:
            return "arrow.clockwise"
        case .downloading:
            return "xmark.circle.fill"
        case nil:
            return "arrow.down.circle.fill"
        }
    }

    private var actionIconColor: Color {
        if deliveryState == .failed || downloadState == .failed {
            return .red
        }
        if deliveryState == .sending || downloadState?.isDownloading == true {
            return HSTheme.secondaryText
        }
        return iconColor
    }

    private var actionAccessibilityLabel: String {
        if isOutgoing {
            switch deliveryState {
            case .sending:
                return "Cancel upload"
            case .failed:
                return "Retry upload"
            case .sent, .read:
                break
            }
        }
        switch downloadState {
        case .downloaded:
            if media?.kind == .webpage {
                return "Open link"
            }
            return media?.kind == .audio || media?.kind == .voice ? "Play audio" : "Open media"
        case .failed:
            return "Retry media download"
        case .downloading:
            return "Cancel media download"
        case nil:
            return "Download media"
        }
    }

    private var transferStatusText: String? {
        if isOutgoing {
            switch deliveryState {
            case .sending:
                if let progress = downloadState?.progress {
                    return "Uploading \(Int(progress * 100))%"
                }
                return "Uploading"
            case .failed:
                return "Upload failed"
            case .sent, .read:
                break
            }
        }
        switch downloadState {
        case .downloading(let progress):
            if let progress {
                return "Downloading \(Int(progress * 100))%"
            }
            return "Downloading"
        case .failed:
            return "Download failed. Tap to retry."
        case .downloaded, nil:
            return nil
        }
    }

    private var transferStatusColor: Color {
        deliveryState == .failed || downloadState == .failed ? .red : secondaryColor
    }

    private var secondaryColor: Color {
        isOutgoing ? HSTheme.Chat.outgoingSecondary : HSTheme.secondaryText
    }

    private var trimmedCaption: String {
        caption.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var webPageURL: URL? {
        guard let preview = media?.webPage else {
            return nil
        }
        return Self.webPageURL(from: preview.url)
            ?? Self.webPageURL(from: preview.embedURL)
            ?? Self.webPageURL(from: preview.displayURL)
    }

    private static func webPageURL(from value: String?) -> URL? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

private struct WebPagePreviewCard: View {
    let preview: HSWebPagePreview
    let tint: Color
    let secondaryColor: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                    }

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HSTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryColor)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let urlText {
                        Text(urlText)
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: mediaIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开链接")
    }

    private var eyebrow: String? {
        nonEmpty(preview.siteName) ?? nonEmpty(preview.type)
    }

    private var title: String {
        nonEmpty(preview.title)
            ?? nonEmpty(preview.displayURL)
            ?? nonEmpty(preview.url)
            ?? "Link Preview"
    }

    private var description: String? {
        nonEmpty(preview.description)
    }

    private var urlText: String? {
        nonEmpty(preview.displayURL) ?? nonEmpty(preview.url)
    }

    private var mediaIconName: String {
        if let document = preview.document {
            switch document.kind {
            case .video:
                return "play.rectangle.fill"
            case .audio, .voice:
                return "waveform"
            case .gif:
                return "sparkles.rectangle.stack"
            case .sticker:
                return "face.smiling"
            default:
                return "doc.richtext"
            }
        }
        if preview.photo != nil {
            return "photo"
        }
        return "link"
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct VoiceMessageWaveformView: View {
    let samples: [Double]
    let tint: Color
    let track: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(samples.prefix(42).enumerated()), id: \.offset) { _, sample in
                Capsule()
                    .fill(sample > 0.16 ? tint : track)
                    .frame(width: 3, height: height(for: sample))
            }
        }
        .frame(height: 26)
        .frame(maxWidth: 220, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func height(for sample: Double) -> CGFloat {
        let normalized = min(1, max(0.08, sample))
        return 6 + CGFloat(normalized) * 20
    }
}

private struct LinkedMessageTextView: UIViewRepresentable {
    let text: String
    let isOutgoing: Bool
    let isInteractionEnabled: Bool
    let onOpen: (MessageTextEntityAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onOpen = onOpen
        textView.isUserInteractionEnabled = isInteractionEnabled
        textView.isSelectable = isInteractionEnabled
        textView.attributedText = attributedText
        textView.linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? min(UIScreen.main.bounds.width * 0.72, 520)
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, width), height: size.height)
    }

    private var attributedText: NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: baseColor
            ]
        )
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var occupiedRanges: [NSRange] = []

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match, let url = match.url else {
                    return
                }
                attributed.addAttributes(linkAttributes(url: url), range: match.range)
                occupiedRanges.append(match.range)
            }
        }

        if let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])([@#][\\p{L}\\p{N}_]{1,64})") {
            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match, !occupiedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else {
                    return
                }
                let token = nsText.substring(with: match.range)
                guard let url = entityURL(for: token) else {
                    return
                }
                attributed.addAttributes(linkAttributes(url: url), range: match.range)
            }
        }

        return attributed
    }

    private var baseColor: UIColor {
        .label
    }

    private var linkColor: UIColor {
        isOutgoing ? UIColor(red: 0.0, green: 0.29, blue: 0.68, alpha: 1.0) : .systemBlue
    }

    private func linkAttributes(url: URL) -> [NSAttributedString.Key: Any] {
        [
            .link: url,
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    private func entityURL(for token: String) -> URL? {
        guard let kind = token.first else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "hsgram"
        components.host = "message-entity"
        components.queryItems = [
            URLQueryItem(name: "type", value: kind == "@" ? "mention" : "hashtag"),
            URLQueryItem(name: "value", value: String(token.dropFirst()))
        ]
        return components.url
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onOpen: (MessageTextEntityAction) -> Void

        init(onOpen: @escaping (MessageTextEntityAction) -> Void) {
            self.onOpen = onOpen
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let action = Self.entityAction(from: URL) {
                onOpen(action)
            } else {
                onOpen(.url(URL))
            }
            return false
        }

        private static func entityAction(from url: URL) -> MessageTextEntityAction? {
            guard url.scheme == "hsgram", url.host == "message-entity" else {
                return nil
            }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let type = components?.queryItems?.first(where: { $0.name == "type" })?.value
            guard let value = components?.queryItems?.first(where: { $0.name == "value" })?.value, !value.isEmpty else {
                return nil
            }
            switch type {
            case "mention":
                return .mention(value)
            case "hashtag":
                return .hashtag(value)
            default:
                return nil
            }
        }
    }
}

private struct ReplyReferenceView: View {
    let messageID: Int64
    let preview: HSMessage?
    let isOutgoing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, 2)
        .accessibilityLabel("Reply to \(title), \(subtitle)")
    }

    private var title: String {
        preview?.authorName ?? "Message #\(messageID)"
    }

    private var subtitle: String {
        guard let preview else {
            return "Tap to load original message"
        }
        if preview.kind == "media" {
            return preview.text.isEmpty ? "Media" : preview.text
        }
        if preview.kind == "service" {
            return preview.text.isEmpty ? "Service update" : preview.text
        }
        return preview.text.isEmpty ? "Message #\(preview.id)" : preview.text
    }

    private var accentColor: Color {
        isOutgoing ? HSTheme.Chat.outgoingSecondary : HSTheme.accent
    }

    private var textColor: Color {
        isOutgoing ? HSTheme.primaryText.opacity(0.72) : HSTheme.secondaryText
    }
}
