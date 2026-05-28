import SwiftUI
import UIKit

enum HSPrototypeTheme {
    static let fallback = ThemeConfig.defaultLight

    static let accent = fallback.primaryAccentColor.color
    static let accentDeep = fallback.primaryAccentColor.color
    static let success = fallback.successColor.color
    static let warning = fallback.destructiveColor.color
    static let orange = fallback.warningColor.color
    static let purple = fallback.primaryAccentColor.color
    static let teal = fallback.secondaryAccentColor.color
    static let background = fallback.groupedBackgroundColor.color
    static let surface = fallback.cardBackgroundColor.color
    static let secondarySurface = fallback.groupedBackgroundColor.color
    static let elevatedSurface = fallback.cardBackgroundColor.color
    static let primaryText = fallback.primaryTextColor.color
    static let secondaryText = fallback.secondaryTextColor.color
    static let tertiaryText = fallback.mutedTextColor.color
    static let separator = fallback.separatorColor.color
    static let incomingBubble = fallback.incomingBubbleColor.color
    static let outgoingBubble = fallback.outgoingBubbleColor.color
    static let unreadMuted = fallback.mutedTextColor.color
    static let glassTint = fallback.navigationBarBackground.color
    static let glassHighlight = fallback.glassStrokeColor.color
    static let glassShadow = fallback.shadowColor.color

    static func accentColor(_ config: ThemeConfig) -> Color {
        config.primaryAccentColor.color
    }

    static func preferredScheme(for config: ThemeConfig) -> ColorScheme? {
        switch config.interfaceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func dynamicTypeSize(for config: ThemeConfig) -> DynamicTypeSize? {
        switch config.fontScale {
        case ..<0.92: return .small
        case 0.92..<1.08: return nil
        case 1.08..<1.18: return .large
        default: return .xLarge
        }
    }
}

enum HSLayoutMetrics {
    static let rootTabBarClearance: CGFloat = 92
    static let chatInputClearance: CGFloat = 22
}

struct HSDynamicTypeScaleModifier: ViewModifier {
    let config: ThemeConfig

    @ViewBuilder
    func body(content: Content) -> some View {
        if let size = HSPrototypeTheme.dynamicTypeSize(for: config) {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func hsDynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct HSChatWallpaperView: View {
    let theme: ChatThemeConfig

    var body: some View {
        ZStack {
            baseLayer

            if theme.chatWallpaperType == .gradientPattern {
                HSLinePatternView(opacity: theme.chatPatternOpacity, ink: patternInk)
            }

            theme.chatWallpaperOverlayColor.color
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var baseLayer: some View {
        switch theme.chatWallpaperType {
        case .defaultLight:
            LinearGradient(
                colors: theme.chatWallpaperGradient.map(\.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solidColor:
            theme.chatWallpaperColor.color
        case .gradient, .gradientPattern:
            LinearGradient(
                colors: theme.chatWallpaperGradient.map(\.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .image, .imageWithOverlay:
            HSGeneratedWallpaperImage(theme: theme)
        case .dark:
            LinearGradient(
                colors: theme.chatWallpaperGradient.map(\.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var patternInk: Color {
        theme.chatPatternInkColor.color
    }
}

struct HSChatBackgroundView: View {
    let style: ChatWallpaperType

    var body: some View {
        HSChatWallpaperView(theme: theme)
    }

    private var theme: ChatThemeConfig {
        switch style {
        case .gradientPattern:
            return .blushPattern
        case .dark:
            return .dark
        default:
            var theme = ChatThemeConfig.defaultLight
            theme.chatWallpaperType = style
            return theme
        }
    }
}

private struct HSGeneratedWallpaperImage: View {
    let theme: ChatThemeConfig

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.chatWallpaperColor.color, theme.chatWallpaperSecondaryColor.color],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, size in
                let colors = [
                    theme.chatWallpaperHighlightColor.color,
                    theme.chatPatternInkColor.color.opacity(0.28)
                ]
                for index in 0..<18 {
                    let x = CGFloat((index * 71) % 390) / 390 * size.width
                    let y = CGFloat((index * 113) % 820) / 820 * size.height
                    let rect = CGRect(x: x - 28, y: y - 20, width: 92, height: 58)
                    var path = Path(roundedRect: rect, cornerRadius: 18)
                    context.fill(path, with: .color(colors[index % colors.count]))
                    path = Path()
                    path.addEllipse(in: CGRect(x: x + 8, y: y + 8, width: 16, height: 16))
                    context.fill(path, with: .color(theme.chatWallpaperHighlightColor.color))
                }
            }
        }
    }
}

private struct HSLinePatternView: View {
    let opacity: Double
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 112
            for row in stride(from: CGFloat(-40), through: size.height + spacing, by: spacing) {
                for column in stride(from: CGFloat(-48), through: size.width + spacing, by: spacing) {
                    drawMotifs(context: context, origin: CGPoint(x: column, y: row))
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private func drawMotifs(context: GraphicsContext, origin: CGPoint) {
        let stroke = GraphicsContext.Shading.color(ink)

        var heart = Path()
        heart.move(to: CGPoint(x: origin.x + 48, y: origin.y + 28))
        heart.addCurve(
            to: CGPoint(x: origin.x + 72, y: origin.y + 28),
            control1: CGPoint(x: origin.x + 52, y: origin.y + 8),
            control2: CGPoint(x: origin.x + 68, y: origin.y + 8)
        )
        heart.addCurve(
            to: CGPoint(x: origin.x + 60, y: origin.y + 54),
            control1: CGPoint(x: origin.x + 90, y: origin.y + 36),
            control2: CGPoint(x: origin.x + 68, y: origin.y + 48)
        )
        heart.addCurve(
            to: CGPoint(x: origin.x + 48, y: origin.y + 28),
            control1: CGPoint(x: origin.x + 52, y: origin.y + 48),
            control2: CGPoint(x: origin.x + 30, y: origin.y + 36)
        )
        context.stroke(heart, with: stroke, lineWidth: 1.8)

        var star = Path()
        star.move(to: CGPoint(x: origin.x + 16, y: origin.y + 20))
        star.addLine(to: CGPoint(x: origin.x + 21, y: origin.y + 30))
        star.addLine(to: CGPoint(x: origin.x + 32, y: origin.y + 31))
        star.addLine(to: CGPoint(x: origin.x + 24, y: origin.y + 38))
        star.addLine(to: CGPoint(x: origin.x + 27, y: origin.y + 49))
        star.addLine(to: CGPoint(x: origin.x + 16, y: origin.y + 43))
        star.addLine(to: CGPoint(x: origin.x + 6, y: origin.y + 49))
        star.addLine(to: CGPoint(x: origin.x + 9, y: origin.y + 38))
        star.addLine(to: CGPoint(x: origin.x + 1, y: origin.y + 31))
        star.addLine(to: CGPoint(x: origin.x + 12, y: origin.y + 30))
        star.closeSubpath()
        context.stroke(star, with: stroke, lineWidth: 1.5)

        var gift = Path(roundedRect: CGRect(x: origin.x + 78, y: origin.y + 72, width: 36, height: 30), cornerRadius: 6)
        context.stroke(gift, with: stroke, lineWidth: 1.6)
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: origin.x + 96, y: origin.y + 72))
        ribbon.addLine(to: CGPoint(x: origin.x + 96, y: origin.y + 102))
        ribbon.move(to: CGPoint(x: origin.x + 78, y: origin.y + 84))
        ribbon.addLine(to: CGPoint(x: origin.x + 114, y: origin.y + 84))
        context.stroke(ribbon, with: stroke, lineWidth: 1.2)

        var flower = Path()
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 3) {
            let center = CGPoint(
                x: origin.x + 36 + cos(angle) * 12,
                y: origin.y + 82 + sin(angle) * 12
            )
            flower.addEllipse(in: CGRect(x: center.x - 7, y: center.y - 5, width: 14, height: 10))
        }
        flower.addEllipse(in: CGRect(x: origin.x + 31, y: origin.y + 77, width: 10, height: 10))
        context.stroke(flower, with: stroke, lineWidth: 1.4)
    }
}
