import SwiftUI
import UIKit

struct HSNavigationBar<Leading: View, Trailing: View>: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String
    var subtitle: String?
    private let leading: Leading
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading.frame(minWidth: 58, alignment: .leading)

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            trailing.frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(data.themeConfig.separatorColor.color.opacity(0.55))
                .frame(height: 1 / UIScreen.main.scale)
        }
    }
}

extension HSNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.leading = EmptyView()
        self.trailing = EmptyView()
    }
}

struct HSFloatingBackButton: View {
    @EnvironmentObject private var data: HSMockChatService
    var title: String?
    var foreground: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: title == nil ? 0 : 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 25, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(foreground ?? data.themeConfig.primaryTextColor.color)
            .frame(width: title == nil ? 56 : nil, height: 56)
            .padding(.horizontal, title == nil ? 0 : 18)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.46), lineWidth: 1 / UIScreen.main.scale)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title ?? "返回")
    }
}

struct HSFloatingChatNavBar: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String
    let subtitle: String
    let avatarInitials: String
    let avatarHex: UInt32
    var isGroup: Bool
    var onBack: () -> Void
    var onProfile: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HSFloatingBackButton(action: onBack)

            Button(action: onProfile) {
                VStack(spacing: 1) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.52), lineWidth: 1 / UIScreen.main.scale)
                }
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 7)
            }
            .buttonStyle(.plain)

            Button(action: onProfile) {
                HSAvatarView(
                    initials: avatarInitials,
                    colorHex: avatarHex,
                    size: 54,
                    isGroup: isGroup
                )
                .overlay {
                    Circle().stroke(Color.white.opacity(0.86), lineWidth: 3)
                }
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct HSSearchBar: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var text: String
    var placeholder = "搜索"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            TextField(placeholder, text: $text)
                .font(.system(size: 18, weight: .regular))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(data.themeConfig.mutedTextColor.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(data.themeConfig.groupedBackgroundColor.color, in: Capsule())
    }
}

struct HSAvatarView: View {
    let initials: String
    let colorHex: UInt32
    var size: CGFloat = 52
    var systemImage: String?
    var isGroup = false
    var isOnline = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(displayText)
                        .font(.system(size: size * (displayText.count > 1 ? 0.34 : 0.48), weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: size, height: size)

            if isOnline {
                Circle()
                    .fill(Color(hex: 0x58C75A))
                    .frame(width: max(12, size * 0.24), height: max(12, size * 0.24))
                    .overlay {
                        Circle().stroke(Color.white, lineWidth: max(2, size * 0.05))
                    }
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var displayText: String {
        let trimmed = initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isGroup ? "群" : "?"
        }
        return String(trimmed.prefix(trimmed.count > 1 && !trimmed.contains(" ") ? 2 : 1)).uppercased()
    }
}

struct HSBadgeView: View {
    @EnvironmentObject private var data: HSMockChatService
    let count: Int
    var muted = false

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, count < 10 ? 7 : 8)
            .frame(minWidth: 22, minHeight: 22)
            .background(
                muted ? data.themeConfig.mutedTextColor.color : data.themeConfig.primaryAccentColor.color,
                in: Capsule()
            )
    }
}

struct HSConversationCell: View {
    @EnvironmentObject private var data: HSMockChatService
    let conversation: Conversation
    var onAvatarTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onAvatarTap) {
                HSAvatarView(
                    initials: conversation.avatarInitials,
                    colorHex: conversation.avatarHex,
                    size: 68,
                    isGroup: conversation.isGroup,
                    isOnline: conversation.participants.contains(where: \.isOnline)
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(conversation.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                .lineLimit(1)
                            if conversation.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                            }
                            if conversation.isMuted {
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(data.themeConfig.mutedTextColor.color)
                            }
                        }

                        if let authorPrefix {
                            Text(authorPrefix)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                .lineLimit(1)
                        }

                        Text(preview)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 4) {
                            if conversation.lastMessage?.isOutgoing == true {
                                HSCheckmarksView(
                                    state: conversation.lastMessage?.deliveryState ?? .sent,
                                    color: data.themeConfig.successColor.color
                                )
                            }
                            Text(HSDateText.shortTime(conversation.updatedAt))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        }
                        if conversation.unreadCount > 0 {
                            HSBadgeView(count: conversation.unreadCount, muted: conversation.isMuted)
                        }
                    }
                }
                .padding(.vertical, 10)

                Rectangle()
                    .fill(data.themeConfig.separatorColor.color.opacity(0.74))
                    .frame(height: 1 / UIScreen.main.scale)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .contentShape(Rectangle())
        .background(data.themeConfig.appBackgroundColor.color)
    }

    private var authorPrefix: String? {
        guard conversation.isGroup, let message = conversation.lastMessage, !message.sender.displayName.isEmpty else {
            return nil
        }
        return message.isOutgoing ? "您自己" : message.sender.displayName
    }

    private var preview: String {
        guard let message = conversation.lastMessage else { return conversation.subtitle }
        if let sticker = message.sticker { return "\(sticker.mood) 贴纸" }
        if let attachment = message.attachment {
            return "\(attachment.title) \(message.body)"
        }
        return message.body.isEmpty ? conversation.subtitle : message.body
    }
}

struct HSReactionBar: View {
    @EnvironmentObject private var data: HSMockChatService
    let reactions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(reactions, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 23))
                        .frame(width: 42, height: 42)
                        .background(data.themeConfig.cardBackgroundColor.color, in: Circle())
                        .shadow(color: Color.black.opacity(0.10), radius: 9, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct HSReactionPill: View {
    @EnvironmentObject private var data: HSMockChatService
    let reaction: MessageReaction
    var compact = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(reaction.emoji)
                    .font(.system(size: compact ? 13 : 16))
                ForEach(Array(visibleInitials.enumerated()), id: \.offset) { index, initials in
                    Text(String(initials.prefix(1)).uppercased())
                        .font(.system(size: compact ? 10 : 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: compact ? 22 : 27, height: compact ? 22 : 27)
                        .background(data.themeConfig.activeChatTheme.reactionAvatarColor.color, in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.32), lineWidth: 1 / UIScreen.main.scale)
                        }
                        .offset(x: index == 0 ? 0 : -4)
                }
                if reaction.count > max(1, visibleInitials.count) {
                    Text("\(reaction.count)")
                        .font(.system(size: compact ? 11 : 13, weight: .semibold))
                        .foregroundStyle(data.themeConfig.outgoingTextColor.color.opacity(0.78))
                }
            }
            .padding(.leading, compact ? 9 : 12)
            .padding(.trailing, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(data.themeConfig.activeChatTheme.reactionPillColor.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var visibleInitials: [String] {
        let initials = reaction.reactorInitials.isEmpty ? ["K"] : reaction.reactorInitials
        return Array(initials.prefix(compact ? 1 : 2))
    }
}

struct HSDateDivider: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(data.themeConfig.activeChatTheme.dateDividerColor.color, in: Capsule())
            .padding(.vertical, 8)
    }
}

struct HSPinnedBanner: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String
    let message: String
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(data.themeConfig.primaryTextColor.color.opacity(0.45))
                .frame(width: 4, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                Text(message)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "pin.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(data.themeConfig.activeChatTheme.pinnedBannerColor.color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.48), lineWidth: 1 / UIScreen.main.scale)
        }
        .padding(.horizontal, 16)
    }
}

struct HSMessageBubble: View {
    @EnvironmentObject private var data: HSMockChatService
    let message: Message
    var showAuthor = false
    var onAvatarTap: () -> Void = {}
    var onReactionTap: (String) -> Void = { _ in }
    var onShowReactionBar: () -> Void = {}
    var onReply: (() -> Void)?
    var onForward: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSelect: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if message.isOutgoing {
                Spacer(minLength: 54)
            } else if showAuthor {
                Button(action: onAvatarTap) {
                    HSAvatarView(
                        initials: message.sender.initials,
                        colorHex: message.sender.accentHex,
                        size: 42,
                        isOnline: message.sender.isOnline
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 42, height: 1)
            }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: -2) {
                bubbleContent
                if !message.reactions.isEmpty {
                    reactionStrip
                        .padding(.top, -8)
                        .padding(.leading, message.isOutgoing ? 0 : 16)
                        .padding(.trailing, message.isOutgoing ? 16 : 0)
                }
            }

            if !message.isOutgoing {
                Spacer(minLength: 54)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, message.kind == .sticker ? 10 : 2)
        .onTapGesture(count: 2) { onReactionTap("♥") }
        .onLongPressGesture(minimumDuration: 0.30) { onShowReactionBar() }
        .contextMenu {
            if !message.body.isEmpty {
                Button {
                    UIPasteboard.general.string = message.body
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
            }
            if let onReply {
                Button(action: onReply) { Label("回复", systemImage: "arrowshape.turn.up.left") }
            }
            if let onForward {
                Button(action: onForward) { Label("转发", systemImage: "arrowshape.turn.up.right") }
            }
            if let onSelect {
                Button(action: onSelect) { Label("选择", systemImage: "checkmark.circle") }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) { Label("删除", systemImage: "trash") }
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.kind == .sticker, let sticker = message.sticker {
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                HSStickerArtwork(sticker: sticker, size: 150)
                statusLine
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(data.themeConfig.activeChatTheme.reactionPillColor.color.opacity(0.68), in: Capsule())
            }
            .frame(maxWidth: 230, alignment: message.isOutgoing ? .trailing : .leading)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                if showAuthor && !message.isOutgoing {
                    authorHeader
                }
                if let forwardSource = message.forwardSource {
                    forwardHeader(forwardSource)
                }
                if let replyPreview = message.replyPreview {
                    replyBlock(replyPreview)
                }
                attachmentContent
                if !message.body.isEmpty {
                    messageText
                }
                statusLine
            }
            .padding(.leading, message.isOutgoing ? 13 : 18)
            .padding(.trailing, message.isOutgoing ? 18 : 13)
            .padding(.vertical, 9)
            .foregroundStyle(message.isOutgoing ? data.themeConfig.outgoingTextColor.color : data.themeConfig.incomingTextColor.color)
            .background(bubbleColor, in: HSMessageBubbleShape(isOutgoing: message.isOutgoing))
            .overlay {
                HSMessageBubbleShape(isOutgoing: message.isOutgoing)
                    .stroke(Color.black.opacity(message.isOutgoing ? 0.08 : 0.10), lineWidth: 1 / UIScreen.main.scale)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.74, 420), alignment: message.isOutgoing ? .trailing : .leading)
        }
    }

    private var authorHeader: some View {
        HStack(spacing: 6) {
            Text(message.sender.displayName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: message.sender.accentHex))
            if let senderRole = message.senderRole {
                Text(senderRole)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(data.themeConfig.primaryAccentColor.color.opacity(0.14), in: Capsule())
            }
        }
    }

    private func forwardHeader(_ source: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(data.themeConfig.secondaryAccentColor.color)
            Text("转发自")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(data.themeConfig.primaryAccentColor.color)
        }
    }

    private func replyBlock(_ preview: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(data.themeConfig.primaryAccentColor.color)
                .frame(width: 3)
            Text(preview)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(message.isOutgoing ? data.themeConfig.outgoingTextColor.color.opacity(0.70) : data.themeConfig.secondaryTextColor.color)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    private var messageText: some View {
        Text(attributedBody)
            .font(.system(size: 19, weight: .regular))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private var attributedBody: AttributedString {
        var attributed = AttributedString(message.body)
        for mention in message.mentions {
            if let range = attributed.range(of: "@\(mention)") {
                attributed[range].foregroundColor = data.themeConfig.secondaryAccentColor.color
                attributed[range].font = .system(size: 19, weight: .semibold)
            }
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let nsText = message.body as NSString
            let full = NSRange(location: 0, length: nsText.length)
            detector.enumerateMatches(in: message.body, range: full) { match, _, _ in
                guard let match else { return }
                let token = nsText.substring(with: match.range)
                guard let attrRange = attributed.range(of: token) else { return }
                attributed[attrRange].foregroundColor = data.themeConfig.secondaryAccentColor.color
            }
        }
        return attributed
    }

    @ViewBuilder
    private var attachmentContent: some View {
        if let attachment = message.attachment {
            switch attachment.kind {
            case .image:
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: attachment.accentHex), data.themeConfig.secondaryAccentColor.color.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                    Image(systemName: attachment.previewSystemImage)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(attachment.subtitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .frame(width: 228)
            case .file, .link, .location, .checklist:
                HStack(spacing: 10) {
                    Image(systemName: attachment.previewSystemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: attachment.accentHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(attachment.title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                        Text(attachment.subtitle)
                            .font(.caption)
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    }
                }
            case .voice:
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(data.themeConfig.primaryAccentColor.color, in: Circle())
                    HStack(spacing: 3) {
                        ForEach(0..<26, id: \.self) { index in
                            Capsule()
                                .fill(data.themeConfig.secondaryAccentColor.color.opacity(index % 3 == 0 ? 0.95 : 0.45))
                                .frame(width: 3, height: CGFloat([9, 18, 12, 24, 14, 20][index % 6]))
                        }
                    }
                    Text(attachment.subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                }
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 16)
            Text(HSDateText.chatTime(message.sentAt))
                .font(.system(size: 13, weight: .regular))
            if message.isOutgoing {
                HSCheckmarksView(state: message.deliveryState, color: statusColor)
            }
        }
        .foregroundStyle(statusColor)
    }

    private var reactionStrip: some View {
        HStack(spacing: 7) {
            ForEach(message.reactions) { reaction in
                HSReactionPill(reaction: reaction) {
                    onReactionTap(reaction.emoji)
                }
            }
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width * 0.74, 420), alignment: message.isOutgoing ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        message.isOutgoing ? data.themeConfig.activeChatTheme.outgoingBubbleColor.color : data.themeConfig.activeChatTheme.incomingBubbleColor.color
    }

    private var statusColor: Color {
        if message.isOutgoing {
            return data.themeConfig.primaryAccentColor.color.opacity(0.82)
        }
        return data.themeConfig.secondaryTextColor.color
    }
}

struct HSMessageInputBar: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var text: String
    var isStickerPanelVisible = false
    var onSend: () -> Void
    var onAttach: () -> Void
    var onEmoji: () -> Void
    var onVoice: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            Button(action: onAttach) {
                Image(systemName: "paperclip")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .frame(width: 56, height: 56)
                    .background(data.themeConfig.inputFieldBackgroundColor.color, in: Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("附件")

            HStack(spacing: 8) {
                TextField("输入消息", text: $text, axis: .vertical)
                    .font(.system(size: 20))
                    .lineLimit(1...5)
                    .padding(.vertical, 13)
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)

                Button(action: onEmoji) {
                    Image(systemName: isStickerPanelVisible ? "keyboard" : "face.smiling")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isStickerPanelVisible ? "键盘" : "贴纸")
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
            .background(data.themeConfig.inputFieldBackgroundColor.color, in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.34), lineWidth: 1 / UIScreen.main.scale)
            }

            Button {
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? onVoice() : onSend()
            } label: {
                Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (isStickerPanelVisible ? "chevron.up" : "mic.fill") : "arrow.up")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .frame(width: 56, height: 56)
                    .background(data.themeConfig.inputFieldBackgroundColor.color, in: Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(data.themeConfig.inputBarBackgroundColor.color.opacity(0.04))
    }
}

struct HSAttachmentSheet: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var isPresented: Bool
    var onPick: (AttachmentKind) -> Void
    @State private var selectedMode = "相册"

    private let modes = ["相册", "文件", "位置", "回复", "核对清单"]

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isPresented = false } }
                VStack(spacing: 0) {
                    Capsule()
                        .fill(data.themeConfig.separatorColor.color.opacity(0.55))
                        .frame(width: 74, height: 7)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isPresented = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                                .frame(width: 54, height: 54)
                                .background(data.themeConfig.cardBackgroundColor.color, in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Menu {
                            ForEach(modes, id: \.self) { mode in
                                Button(mode) { selectedMode = mode }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("最近")
                                    .font(.system(size: 20, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(data.themeConfig.primaryTextColor.color)
                        }

                        Spacer()

                        Color.clear.frame(width: 54, height: 54)
                    }
                    .padding(.horizontal, 18)

                    photoGrid
                        .padding(.top, 12)

                    HSTranslucentAttachmentModeBar(selectedMode: $selectedMode, modes: modes) { mode in
                        onPick(kind(for: mode))
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isPresented = false }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 18)
                }
                .background(data.themeConfig.sheetBackgroundColor.color, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1 / UIScreen.main.scale)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.86), value: isPresented)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                Button {
                    onPick(.image)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isPresented = false }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        index == 0 ? Color(hex: 0x462214) : data.themeConfig.primaryAccentColor.color.opacity(0.10 + Double(index % 4) * 0.10),
                                        data.themeConfig.secondaryAccentColor.color.opacity(0.16 + Double(index % 3) * 0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .aspectRatio(1, contentMode: .fit)
                        if index != 0 {
                            Image(systemName: index % 2 == 0 ? "photo" : "square.text.square")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(systemName: "camera")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                        Circle()
                            .stroke(Color.white.opacity(0.86), lineWidth: 2)
                            .frame(width: 34, height: 34)
                            .padding(8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: 430)
    }

    private func kind(for mode: String) -> AttachmentKind {
        switch mode {
        case "文件": return .file
        case "位置": return .location
        case "回复": return .link
        case "核对清单": return .checklist
        default: return .image
        }
    }
}

private struct HSTranslucentAttachmentModeBar: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var selectedMode: String
    let modes: [String]
    var onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { mode in
                Button {
                    selectedMode = mode
                    onTap(mode)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 25, weight: .semibold))
                        Text(mode)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selectedMode == mode ? data.themeConfig.primaryAccentColor.color : data.themeConfig.primaryTextColor.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background {
                        if selectedMode == mode {
                            Circle()
                                .fill(data.themeConfig.primaryAccentColor.color.opacity(0.13))
                                .frame(width: 74, height: 74)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func icon(for mode: String) -> String {
        switch mode {
        case "文件": return "doc.fill"
        case "位置": return "mappin.circle.fill"
        case "回复": return "arrowshape.turn.up.left.fill"
        case "核对清单": return "checkmark.square.fill"
        default: return "photo.fill"
        }
    }
}

struct HSStickerPanel: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var isPresented: Bool
    var onPick: (HSSticker) -> Void
    @State private var query = ""
    @State private var selectedMode = "贴纸"

    private let modes = ["GIF 动态图", "贴纸", "表情"]

    var body: some View {
        VStack(spacing: 0) {
            if isPresented {
                HStack(spacing: 18) {
                    Button(action: {}) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 26, weight: .medium))
                    }
                    Button(action: {}) {
                        Image(systemName: "clock")
                            .font(.system(size: 28, weight: .medium))
                    }
                    Spacer()
                }
                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 18)

                HSSearchBar(text: $query, placeholder: "搜索")
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                HStack {
                    Spacer()
                    Text("最近使用")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                        ForEach(filteredStickers) { sticker in
                            Button {
                                onPick(sticker)
                            } label: {
                                HSStickerArtwork(sticker: sticker, size: 66)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 90)
                }
                .frame(height: 288)

                HStack(spacing: 12) {
                    HSCapsuleSegmentedControl(selection: $selectedMode, items: modes)
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(data.themeConfig.primaryTextColor.color)
                            .frame(width: 58, height: 58)
                            .background(data.themeConfig.cardBackgroundColor.color.opacity(0.80), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(data.themeConfig.inputBarBackgroundColor.color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(data.themeConfig.separatorColor.color.opacity(0.32))
                .frame(height: 1 / UIScreen.main.scale)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var filteredStickers: [HSSticker] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return data.stickers
        }
        return data.stickers.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
                $0.mood.localizedCaseInsensitiveContains(query)
        }
    }
}

struct HSStickerArtwork: View {
    let sticker: HSSticker
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: sticker.baseHex).opacity(0.98), Color(hex: sticker.accentHex).opacity(0.82)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.72
                    )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(0.56))
                        .frame(width: size * 0.18, height: size * 0.18)
                        .offset(x: size * 0.18, y: size * 0.13)
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(0.50), lineWidth: 2)
                }
            Image(systemName: sticker.symbol)
                .font(.system(size: size * 0.43, weight: .black))
                .foregroundStyle(Color(hex: sticker.accentHex == sticker.baseHex ? 0x1E1E22 : sticker.accentHex))
                .shadow(color: Color.white.opacity(0.52), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(sticker.mood == "睡觉" ? -8 : 0))
        .accessibilityLabel(sticker.title)
    }
}

struct HSGroupProfileHeader: View {
    @EnvironmentObject private var data: HSMockChatService
    let group: HSGroup
    var mode: Mode = .large
    var onBack: () -> Void
    var onEdit: () -> Void
    var onAction: (String) -> Void

    enum Mode {
        case large
        case avatar
    }

    var body: some View {
        VStack(spacing: 0) {
            if mode == .large {
                largeHeader
            } else {
                avatarHeader
            }
            actionButtons
        }
    }

    private var largeHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: group.avatarHex).opacity(0.55), Color(hex: 0xC8D6E7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                HSAvatarView(initials: group.avatarInitials, colorHex: group.avatarHex, size: 220, isGroup: true)
                    .opacity(0.18)
                    .scaleEffect(1.6)
            }
            .frame(height: 448)
            .clipped()

            HStack(alignment: .top) {
                HSFloatingBackButton(foreground: .white, action: onBack)
                Spacer()
                Button(action: onEdit) {
                    HStack(spacing: 12) {
                        Image(systemName: "crop.rotate")
                        Text("编辑")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.black.opacity(0.34), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.title)
                    .font(.system(size: 29, weight: .bold))
                Text("\(group.memberCount) 位成员")
                    .font(.system(size: 21, weight: .regular))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.bottom, 94)
        }
    }

    private var avatarHeader: some View {
        VStack(spacing: 18) {
            HStack {
                HSFloatingBackButton(action: onBack)
                Spacer()
                Button("编辑", action: onEdit)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            HSAvatarView(initials: group.avatarInitials, colorHex: group.avatarHex, size: 126, isGroup: true)
            VStack(spacing: 4) {
                Text(group.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                Text("\(group.memberCount) 位成员")
                    .font(.system(size: 18))
                    .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            }
        }
        .padding(.bottom, 24)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            profileAction("静音", "bell.fill")
            profileAction("搜索", "magnifyingglass")
            profileAction("更多", "ellipsis")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func profileAction(_ title: String, _ icon: String) -> some View {
        Button {
            onAction(title)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(mode == .large ? .white : data.themeConfig.primaryAccentColor.color)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(mode == .large ? Color.white.opacity(0.20) : data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HSGroupedSettingsCard<Content: View>: View {
    @EnvironmentObject private var data: HSMockChatService
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

struct HSSettingsRow: View {
    @EnvironmentObject private var data: HSMockChatService
    let icon: String
    let title: String
    var subtitle: String?
    var value: String?
    var accent: Color?
    var showsDisclosure = true
    var toggle: Binding<Bool>?
    var action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        accent: Color? = nil,
        showsDisclosure: Bool = true,
        toggle: Binding<Bool>? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.accent = accent
        self.showsDisclosure = showsDisclosure
        self.toggle = toggle
        self.action = action
    }

    init(item: SettingsItem) {
        self.icon = item.icon
        self.title = item.title
        self.subtitle = item.subtitle
        self.value = nil
        self.accent = Color(hex: item.accentHex)
        self.showsDisclosure = true
        self.toggle = nil
        self.action = nil
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(accent ?? data.themeConfig.primaryAccentColor.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                if let toggle {
                    Toggle("", isOn: toggle)
                        .labelsHidden()
                        .tint(data.themeConfig.successColor.color)
                } else {
                    if let value {
                        Text(value)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                            .lineLimit(1)
                    }
                    if showsDisclosure {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(data.themeConfig.mutedTextColor.color)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil && toggle == nil)
    }
}

struct HSMemberRow: View {
    @EnvironmentObject private var data: HSMockChatService
    let user: User
    var role: String?
    var showSeparator = true

    var body: some View {
        HStack(spacing: 14) {
            HSAvatarView(initials: user.initials, colorHex: user.accentHex, size: 58, isOnline: user.isOnline)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                Text(user.isOnline ? "在线" : user.lastSeenText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(user.isOnline ? data.themeConfig.primaryAccentColor.color : data.themeConfig.secondaryTextColor.color)
                    .lineLimit(1)
            }
            Spacer()
            if let role {
                Text(role)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(role == "所有者" ? data.themeConfig.primaryAccentColor.color : data.themeConfig.successColor.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((role == "所有者" ? data.themeConfig.primaryAccentColor.color : data.themeConfig.successColor.color).opacity(0.14), in: Capsule())
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if showSeparator {
                Rectangle()
                    .fill(data.themeConfig.separatorColor.color.opacity(0.72))
                    .frame(height: 1 / UIScreen.main.scale)
                    .padding(.leading, 90)
            }
        }
    }
}

struct HSPermissionRow: View {
    @EnvironmentObject private var data: HSMockChatService
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(isOn ? data.themeConfig.successColor.color : data.themeConfig.destructiveColor.color)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

struct HSSliderControl: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double
    let labels: [String]
    var centerTitle: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(labels.first ?? "")
                Spacer()
                Text(centerTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(data.themeConfig.primaryTextColor.color)
                Spacer()
                Text(labels.last ?? "")
            }
            .font(.system(size: 16))
            .foregroundStyle(data.themeConfig.secondaryTextColor.color)
            Slider(value: $value, in: bounds, step: step)
                .tint(data.themeConfig.primaryAccentColor.color)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(data.themeConfig.cardBackgroundColor.color, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

struct HSCapsuleSegmentedControl: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var selection: String
    let items: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        selection = item
                    }
                } label: {
                    Text(item)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(data.themeConfig.primaryTextColor.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(data.themeConfig.groupedBackgroundColor.color)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(data.themeConfig.cardBackgroundColor.color.opacity(0.88), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.60), lineWidth: 1 / UIScreen.main.scale)
        }
    }
}

struct HSTranslucentTabBar: View {
    @EnvironmentObject private var data: HSMockChatService
    @Binding var selection: HSAppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HSAppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 25, weight: .semibold))
                            .frame(height: 28)
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? data.themeConfig.primaryAccentColor.color : data.themeConfig.primaryTextColor.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(data.themeConfig.groupedBackgroundColor.color.opacity(0.78))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.50), lineWidth: 1 / UIScreen.main.scale)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

struct HSTabBar: View {
    @Binding var selection: HSAppTab

    var body: some View {
        HSTranslucentTabBar(selection: $selection)
    }
}

struct HSEmptyStateView: View {
    @EnvironmentObject private var data: HSMockChatService
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(data.themeConfig.primaryAccentColor.color)
                .frame(width: 94, height: 94)
                .background(data.themeConfig.primaryAccentColor.color.opacity(0.12), in: Circle())
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(data.themeConfig.primaryTextColor.color)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(data.themeConfig.primaryAccentColor.color, in: Capsule())
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HSCheckmarksView: View {
    let state: MessageDeliveryState
    let color: Color

    var body: some View {
        Group {
            switch state {
            case .sending:
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .bold))
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
            case .delivered, .read:
                ZStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .offset(x: -3)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .offset(x: 3)
                }
                .frame(width: 22)
            }
        }
        .foregroundStyle(color)
        .accessibilityLabel(state == .read ? "已读" : "已发送")
    }
}

private struct HSMessageBubbleShape: Shape {
    let isOutgoing: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 22
        let tail: CGFloat = 8
        let bodyRect = isOutgoing
            ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
            : CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: radius, height: radius))
        if isOutgoing {
            path.move(to: CGPoint(x: bodyRect.maxX - 7, y: bodyRect.maxY - 17))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - 3),
                control: CGPoint(x: bodyRect.maxX + 3, y: bodyRect.maxY - 7)
            )
            path.addQuadCurve(
                to: CGPoint(x: bodyRect.maxX - 12, y: bodyRect.maxY - 8),
                control: CGPoint(x: bodyRect.maxX + 1, y: bodyRect.maxY)
            )
        } else {
            path.move(to: CGPoint(x: bodyRect.minX + 7, y: bodyRect.maxY - 17))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - 3),
                control: CGPoint(x: bodyRect.minX - 3, y: bodyRect.maxY - 7)
            )
            path.addQuadCurve(
                to: CGPoint(x: bodyRect.minX + 12, y: bodyRect.maxY - 8),
                control: CGPoint(x: bodyRect.minX - 1, y: bodyRect.maxY)
            )
        }
        return path
    }
}
