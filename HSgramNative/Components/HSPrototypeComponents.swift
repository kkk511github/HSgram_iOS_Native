import SwiftUI
import UIKit

struct HSNavigationBar: View {
    let title: String
    var subtitle: String?
    private let leading: AnyView
    private let trailing: AnyView

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.leading = AnyView(EmptyView())
        self.trailing = AnyView(EmptyView())
    }

    init<Leading: View, Trailing: View>(title: String, subtitle: String? = nil, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.leading = AnyView(leading())
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(spacing: 12) {
            leading.frame(minWidth: 28, alignment: .leading)
            VStack(spacing: 2) {
                Text(title).font(.headline.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            trailing.frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [HSPrototypeTheme.glassHighlight.opacity(0.36), HSPrototypeTheme.glassTint.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.2)).frame(height: 1 / UIScreen.main.scale) }
    }
}

struct HSSearchBar: View {
    @Binding var text: String
    var placeholder = "搜索"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold)).foregroundStyle(HSPrototypeTheme.secondaryText)
            TextField(placeholder, text: $text).font(.body).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HSPrototypeTheme.tertiaryText) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1 / UIScreen.main.scale)
        }
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
                Circle().fill(LinearGradient(colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing))
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
                } else if isGroup {
                    Image(systemName: "person.2.fill").font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.white)
                } else {
                    Text(initials.prefix(2).uppercased()).font(.system(size: size * 0.34, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            if isOnline {
                HSOnlineStatusView(size: max(12, size * 0.26)).offset(x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct HSOnlineStatusView: View {
    var size: CGFloat = 14
    var body: some View {
        Circle().fill(HSPrototypeTheme.success).frame(width: size, height: size).overlay { Circle().stroke(HSPrototypeTheme.surface, lineWidth: max(2, size * 0.18)) }
    }
}

struct HSBadgeView: View {
    let count: Int
    var muted = false
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count < 10 ? 7 : 8)
            .frame(minWidth: 22, minHeight: 22)
            .background(muted ? HSPrototypeTheme.unreadMuted : HSPrototypeTheme.accent, in: Capsule())
    }
}

struct HSConversationCell: View {
    let conversation: Conversation
    var onAvatarTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAvatarTap) {
                HSAvatarView(initials: conversation.avatarInitials, colorHex: conversation.avatarHex, size: 54, isGroup: conversation.isGroup, isOnline: conversation.participants.contains(where: \.isOnline))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if conversation.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(HSPrototypeTheme.tertiaryText) }
                    Text(conversation.title).font(.body.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText).lineLimit(1)
                    if conversation.isMuted { Image(systemName: "bell.slash.fill").font(.caption).foregroundStyle(HSPrototypeTheme.tertiaryText) }
                    Spacer(minLength: 8)
                    Text(HSDateText.shortTime(conversation.updatedAt)).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(preview).font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if conversation.unreadCount > 0 { HSBadgeView(count: conversation.unreadCount, muted: conversation.isMuted) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(conversation.isPinned ? HSPrototypeTheme.secondarySurface.opacity(0.65) : HSPrototypeTheme.surface)
        .contentShape(Rectangle())
    }

    private var preview: String {
        guard let message = conversation.lastMessage else { return conversation.subtitle }
        if let attachment = message.attachment { return "\(attachment.title)  \(message.body)" }
        return message.body
    }
}

struct HSReactionBar: View {
    let reactions: [String]
    var onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(reactions, id: \.self) { emoji in
                Button { onSelect(emoji) } label: {
                    Text(emoji).font(.system(size: 24)).frame(width: 38, height: 38).background(HSPrototypeTheme.surface, in: Circle()).shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct HSContextMenu: ViewModifier {
    var onCopy: (() -> Void)?
    var onReply: (() -> Void)?
    var onForward: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSelect: (() -> Void)?

    func body(content: Content) -> some View {
        content.contextMenu {
            if let onCopy {
                Button(action: onCopy) { Label("复制", systemImage: "doc.on.doc") }
            }
            if let onReply {
                Button(action: onReply) { Label("回复", systemImage: "arrowshape.turn.up.left") }
            }
            if let onForward {
                Button(action: onForward) { Label("转发", systemImage: "arrowshape.turn.up.right") }
            }
            if let onSelect {
                Button(action: onSelect) { Label("多选", systemImage: "checkmark.circle") }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) { Label("删除", systemImage: "trash") }
            }
        }
    }
}

extension View {
    func hsContextMenu(onCopy: (() -> Void)? = nil, onReply: (() -> Void)? = nil, onForward: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onSelect: (() -> Void)? = nil) -> some View {
        modifier(HSContextMenu(onCopy: onCopy, onReply: onReply, onForward: onForward, onDelete: onDelete, onSelect: onSelect))
    }
}

struct HSMessageBubble: View {
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
                Spacer(minLength: 42)
            } else if showAuthor {
                Button(action: onAvatarTap) { HSAvatarView(initials: message.sender.initials, colorHex: message.sender.accentHex, size: 30, isOnline: message.sender.isOnline) }.buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 30, height: 1)
            }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 7) {
                    if showAuthor && !message.isOutgoing {
                        HStack(spacing: 6) {
                            Text(message.sender.displayName).font(.caption.weight(.semibold)).foregroundStyle(Color(hex: message.sender.accentHex))
                            if let senderRole = message.senderRole {
                                Text(senderRole).font(.caption2.weight(.bold)).foregroundStyle(HSPrototypeTheme.accent).padding(.horizontal, 5).padding(.vertical, 2).background(HSPrototypeTheme.accent.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    if let replyPreview = message.replyPreview {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(message.isOutgoing ? .white.opacity(0.62) : HSPrototypeTheme.accent).frame(width: 3)
                            Text(replyPreview).font(.caption).foregroundStyle(message.isOutgoing ? .white.opacity(0.88) : HSPrototypeTheme.secondaryText).lineLimit(2)
                        }
                        .padding(8)
                        .background(Color.black.opacity(message.isOutgoing ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                    attachmentContent
                    if !message.body.isEmpty { messageText }
                    HStack(spacing: 4) {
                        Text(HSDateText.chatTime(message.sentAt)).font(.caption2)
                        if message.isOutgoing { deliveryIcon }
                    }
                    .foregroundStyle(message.isOutgoing ? .white.opacity(0.82) : HSPrototypeTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(message.isOutgoing ? .white : HSPrototypeTheme.primaryText)
                .background(bubbleFill, in: HSMessageBubbleShape(isOutgoing: message.isOutgoing))
                .overlay {
                    if !message.isOutgoing { HSMessageBubbleShape(isOutgoing: false).stroke(HSPrototypeTheme.separator.opacity(0.3), lineWidth: 1 / UIScreen.main.scale) }
                }
                .frame(maxWidth: 292, alignment: message.isOutgoing ? .trailing : .leading)
                if !message.reactions.isEmpty { reactionStrip }
            }
            if !message.isOutgoing { Spacer(minLength: 42) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .onTapGesture(count: 2) { onReactionTap("❤️") }
        .onLongPressGesture(minimumDuration: 0.32) { onShowReactionBar() }
        .hsContextMenu(
            onCopy: message.body.isEmpty ? nil : { UIPasteboard.general.string = message.body },
            onReply: onReply,
            onForward: onForward,
            onDelete: onDelete,
            onSelect: onSelect
        )
    }

    private var bubbleFill: AnyShapeStyle {
        if message.isOutgoing {
            return AnyShapeStyle(LinearGradient(colors: [HSPrototypeTheme.accent, HSPrototypeTheme.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(HSPrototypeTheme.incomingBubble)
    }

    private var messageText: some View {
        Text(highlightMentions(message.body)).font(.body).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
    }

    private var attachmentContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let attachment = message.attachment {
                switch attachment.kind {
                case .image:
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [Color(hex: attachment.accentHex).opacity(0.9), Color(hex: 0x7DD3FC)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 224, height: 146)
                        Image(systemName: attachment.previewSystemImage).font(.system(size: 38, weight: .semibold)).foregroundStyle(.white.opacity(0.9)).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text(attachment.subtitle).font(.caption.weight(.semibold)).foregroundStyle(.white).padding(8)
                    }
                case .file, .link:
                    HStack(spacing: 10) {
                        Image(systemName: attachment.previewSystemImage).font(.title2.weight(.semibold)).foregroundStyle(.white).frame(width: 42, height: 42).background(Color(hex: attachment.accentHex), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(attachment.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(attachment.subtitle).font(.caption).foregroundStyle(message.isOutgoing ? .white.opacity(0.75) : HSPrototypeTheme.secondaryText)
                        }
                    }
                case .voice:
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.caption.weight(.bold)).foregroundStyle(message.isOutgoing ? HSPrototypeTheme.accent : .white).frame(width: 34, height: 34).background(message.isOutgoing ? .white : HSPrototypeTheme.accent, in: Circle())
                        HStack(spacing: 3) {
                            ForEach(0..<24, id: \.self) { index in
                                Capsule().fill(message.isOutgoing ? .white.opacity(0.8) : HSPrototypeTheme.accent.opacity(0.75)).frame(width: 3, height: CGFloat([8, 16, 10, 22, 14, 19][index % 6]))
                            }
                        }
                        Text(attachment.subtitle).font(.caption.monospacedDigit()).foregroundStyle(message.isOutgoing ? .white.opacity(0.82) : HSPrototypeTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var deliveryIcon: some View {
        Image(systemName: message.deliveryState == .read ? "checkmark.circle.fill" : message.deliveryState == .sending ? "clock" : "checkmark")
            .font(.caption2.weight(.bold))
    }

    private var reactionStrip: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions) { reaction in
                Button { onReactionTap(reaction.emoji) } label: {
                    HStack(spacing: 3) {
                        Text(reaction.emoji)
                        Text("\(reaction.count)").font(.caption2.weight(.semibold))
                    }
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(reaction.isSelectedByCurrentUser ? HSPrototypeTheme.accent.opacity(0.16) : HSPrototypeTheme.surface, in: Capsule())
                    .overlay { Capsule().stroke(HSPrototypeTheme.separator.opacity(0.45), lineWidth: 1 / UIScreen.main.scale) }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 292, alignment: message.isOutgoing ? .trailing : .leading)
    }

    private func highlightMentions(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for mention in message.mentions {
            if let range = attributed.range(of: "@\(mention)") {
                attributed[range].foregroundColor = message.isOutgoing ? .white : HSPrototypeTheme.accent
                attributed[range].font = .body.bold()
            }
        }
        return attributed
    }
}

private struct HSMessageBubbleShape: Shape {
    let isOutgoing: Bool
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tail: CGFloat = 7
        let bodyRect = isOutgoing ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height) : CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: radius, height: radius))
        if isOutgoing {
            path.move(to: CGPoint(x: bodyRect.maxX - 6, y: bodyRect.maxY - 16))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 3), control: CGPoint(x: bodyRect.maxX + 2, y: bodyRect.maxY - 6))
            path.addQuadCurve(to: CGPoint(x: bodyRect.maxX - 10, y: bodyRect.maxY - 8), control: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY))
        } else {
            path.move(to: CGPoint(x: bodyRect.minX + 6, y: bodyRect.maxY - 16))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 3), control: CGPoint(x: bodyRect.minX - 2, y: bodyRect.maxY - 6))
            path.addQuadCurve(to: CGPoint(x: bodyRect.minX + 10, y: bodyRect.maxY - 8), control: CGPoint(x: bodyRect.minX, y: bodyRect.maxY))
        }
        return path
    }
}

struct HSMessageInputBar: View {
    @Binding var text: String
    var onSend: () -> Void
    var onAttach: () -> Void
    var onEmoji: () -> Void
    var onVoice: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: onEmoji) { Image(systemName: "face.smiling").font(.system(size: 22)).frame(width: 32, height: 32) }
                .buttonStyle(.plain).foregroundStyle(HSPrototypeTheme.secondaryText).accessibilityLabel("表情")
            HStack(alignment: .bottom, spacing: 6) {
                TextField("输入消息", text: $text, axis: .vertical).font(.body).lineLimit(1...5).padding(.vertical, 8)
                Button(action: onAttach) { Image(systemName: "paperclip").font(.system(size: 20)).frame(width: 30, height: 30) }
                    .buttonStyle(.plain).foregroundStyle(HSPrototypeTheme.secondaryText).accessibilityLabel("附件")
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1 / UIScreen.main.scale) }
            .shadow(color: HSPrototypeTheme.glassShadow.opacity(0.08), radius: 12, x: 0, y: 4)
            Button { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? onVoice() : onSend() } label: {
                Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up.circle.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(HSPrototypeTheme.accent).frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.2)).frame(height: 1 / UIScreen.main.scale) }
    }
}

struct HSSettingsRow: View {
    let item: SettingsItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 34, height: 34).background(Color(hex: item.accentHex), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
                Text(item.subtitle).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(HSPrototypeTheme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(HSPrototypeTheme.surface)
    }
}

struct HSEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(HSPrototypeTheme.accent.opacity(0.11)).frame(width: 92, height: 92)
                Image(systemName: systemImage).font(.system(size: 38, weight: .semibold)).foregroundStyle(HSPrototypeTheme.accent)
            }
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
            Text(message).font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 26)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct HSTabBar: View {
    @Binding var selection: HSAppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(HSAppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon).font(.system(size: 20, weight: .semibold))
                        Text(tab.title).font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? HSPrototypeTheme.accent : HSPrototypeTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 10)
        .padding(.bottom, 2)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [HSPrototypeTheme.glassTint.opacity(0.06), HSPrototypeTheme.glassHighlight.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.2)).frame(height: 1 / UIScreen.main.scale) }
        .shadow(color: HSPrototypeTheme.glassShadow.opacity(0.16), radius: 18, x: 0, y: -8)
    }
}
