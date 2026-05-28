import SwiftUI
import UIKit

enum HSTheme {
    static let accent = Color(rgb: 0x0088ff)
    static let accentPressed = Color(rgb: 0x007aff)
    static let trust = Color(rgb: 0x35c759)
    static let circle = Color(rgb: 0xf09a37)
    static let warning = Color(rgb: 0xcf3030)
    static let primaryText = Color(rgb: 0x000000)
    static let secondaryText = Color(rgb: 0x8e8e93)
    static let placeholder = Color(rgb: 0xc8c8ce)
    static let disclosure = Color(rgb: 0xbab9be)
    static let separator = Color(rgb: 0xc8c7cc)
    static let highlighted = Color(rgb: 0xe5e5ea)
    static let surface = Color(rgb: 0xffffff)
    static let grouped = Color(rgb: 0xefeff4)

    enum Chat {
        static let listBackground = Color(rgb: 0xffffff)
        static let rowBackground = Color(rgb: 0xffffff)
        static let dateText = Color(rgb: 0x8e8e93)
        static let incomingBubble = Color(rgb: 0xffffff)
        static let outgoingBubble = Color(rgb: 0xe1ffc7)
        static let outgoingSecondary = Color(rgb: 0x008c09).opacity(0.8)
        static let composerBackground = Color(rgb: 0xf7f7f7).opacity(0.94)
        static let composerStroke = Color.black.opacity(0.10)
        static let panelControlColor = Color.black
        static let panelSeparatorColor = Color(rgb: 0xbec2c6)
        static let wallpaper = Color(rgb: 0xdce8f3)
        static let servicePill = Color.black.opacity(0.18)
        static let inputFill = Color(rgb: 0xffffff).opacity(0.92)
        static let inputPlaceholder = Color(rgb: 0x9b9ba1)
    }

    enum RootTab {
        static let text = Color(rgb: 0x6e6e73)
        static let selection = Color(rgb: 0x0088ff).opacity(0.12)
        static let stroke = Color.white.opacity(0.44)
    }
}

extension Color {
    init(rgb: UInt32, alpha: Double = 1.0) {
        let red = Double((rgb >> 16) & 0xff) / 255.0
        let green = Double((rgb >> 8) & 0xff) / 255.0
        let blue = Double(rgb & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct HSCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HSTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HSTheme.separator.opacity(0.65))
                    .frame(height: 1 / UIScreen.main.scale)
            }
    }
}

struct HSMetricCard: View {
    let value: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct HSErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(HSTheme.warning)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HSTheme.warning.opacity(0.08))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(HSTheme.warning)
                    .frame(width: 3)
            }
    }
}

struct HSActionRow: View {
    let title: String
    let subtitle: String
    let badge: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            .padding(14)
            .background(HSTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HSTheme.separator.opacity(0.65))
                    .frame(height: 1 / UIScreen.main.scale)
                    .padding(.leading, 66)
            }
        }
        .buttonStyle(.plain)
    }
}

struct HSClassicAvatar: View {
    let title: String
    let icon: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.72), tint.opacity(0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: icon)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct HSClassicUnreadBadge: View {
    let count: Int
    var muted: Bool = false

    var body: some View {
        Text(count > 999 ? "999+" : "\(count)")
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, count < 10 ? 7 : 8)
            .frame(minWidth: 22, minHeight: 22)
            .background(muted ? Color(rgb: 0xbcbcc3) : HSTheme.accent, in: Capsule())
    }
}

struct HSChatWallpaper: View {
    var body: some View {
        ZStack {
            HSTheme.Chat.wallpaper
            Canvas { context, size in
                let spacing: CGFloat = 38
                let ink = Color.white.opacity(0.22)
                for x in stride(from: -spacing, through: size.width + spacing, by: spacing) {
                    for y in stride(from: -spacing, through: size.height + spacing, by: spacing) {
                        var dot = Path()
                        dot.addEllipse(in: CGRect(x: x, y: y, width: 3, height: 3))
                        context.fill(dot, with: .color(ink))

                        var leaf = Path()
                        leaf.move(to: CGPoint(x: x + 15, y: y + 7))
                        leaf.addQuadCurve(
                            to: CGPoint(x: x + 25, y: y + 16),
                            control: CGPoint(x: x + 27, y: y + 5)
                        )
                        leaf.addQuadCurve(
                            to: CGPoint(x: x + 15, y: y + 7),
                            control: CGPoint(x: x + 14, y: y + 17)
                        )
                        context.stroke(leaf, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
                    }
                }
            }
        }
    }
}

struct HSChatBubbleShape: Shape {
    let isOutgoing: Bool

    func path(in rect: CGRect) -> Path {
        let corner: CGFloat = 17
        let tail: CGFloat = 7
        var path = Path()

        if isOutgoing {
            let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
            path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: corner, height: corner))
            path.move(to: CGPoint(x: bubbleRect.maxX - 6, y: bubbleRect.maxY - 15))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - 3),
                control: CGPoint(x: bubbleRect.maxX + 2, y: bubbleRect.maxY - 6)
            )
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.maxX - 10, y: bubbleRect.maxY - 7),
                control: CGPoint(x: bubbleRect.maxX - 1, y: bubbleRect.maxY - 1)
            )
        } else {
            let bubbleRect = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
            path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: corner, height: corner))
            path.move(to: CGPoint(x: bubbleRect.minX + 6, y: bubbleRect.maxY - 15))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - 3),
                control: CGPoint(x: bubbleRect.minX - 2, y: bubbleRect.maxY - 6)
            )
            path.addQuadCurve(
                to: CGPoint(x: bubbleRect.minX + 10, y: bubbleRect.maxY - 7),
                control: CGPoint(x: bubbleRect.minX + 1, y: bubbleRect.maxY - 1)
            )
        }

        return path
    }
}
