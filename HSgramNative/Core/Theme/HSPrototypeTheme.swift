import SwiftUI
import UIKit

enum HSPrototypeTheme {
    static let accent = Color(hex: 0x168BFF)
    static let accentDeep = Color(hex: 0x0875DA)
    static let success = Color(hex: 0x34C759)
    static let warning = Color(hex: 0xFF3B30)
    static let orange = Color(hex: 0xFF9500)
    static let purple = Color(hex: 0xAF52DE)
    static let teal = Color(hex: 0x30B7C5)

    static let background = Color.hsDynamic(light: 0xF4F6F9, dark: 0x080A0D)
    static let surface = Color.hsDynamic(light: 0xFFFFFF, dark: 0x171A20)
    static let secondarySurface = Color.hsDynamic(light: 0xEEF2F6, dark: 0x22262D)
    static let elevatedSurface = Color.hsDynamic(light: 0xFFFFFF, dark: 0x20242C)
    static let primaryText = Color.hsDynamic(light: 0x111318, dark: 0xF6F7F9)
    static let secondaryText = Color.hsDynamic(light: 0x777E89, dark: 0x9CA3AF)
    static let tertiaryText = Color.hsDynamic(light: 0xA7ADB7, dark: 0x707783)
    static let separator = Color.hsDynamic(light: 0xD9DEE7, dark: 0x2F3540)
    static let incomingBubble = Color.hsDynamic(light: 0xFFFFFF, dark: 0x20242C)
    static let outgoingBubble = Color.hsDynamic(light: 0xDDF4FF, dark: 0x0E4C73)
    static let unreadMuted = Color.hsDynamic(light: 0xB8BEC9, dark: 0x5D6673)
    static let glassTint = Color.hsDynamic(light: 0xFFFFFF, dark: 0x111823)
    static let glassHighlight = Color.hsDynamic(light: 0xFFFFFF, dark: 0x2E3947)
    static let glassShadow = Color.black.opacity(0.14)

    static func accentColor(_ config: ThemeConfig) -> Color {
        Color(hex: config.accentHex)
    }

    static func preferredScheme(for config: ThemeConfig) -> ColorScheme? {
        switch config.interfaceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum HSLayoutMetrics {
    static let rootTabBarClearance: CGFloat = 88
    static let chatInputClearance: CGFloat = 18
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

struct HSChatBackgroundView: View {
    let style: ChatBackgroundStyle

    var body: some View {
        ZStack {
            switch style {
            case .clean:
                HSPrototypeTheme.background
            case .mist:
                LinearGradient(
                    colors: [
                        Color.hsDynamic(light: 0xEAF6FF, dark: 0x101820),
                        Color.hsDynamic(light: 0xF7FAFC, dark: 0x0A0D11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .pattern:
                HSPrototypeTheme.background
                Canvas { context, size in
                    let dot = Color.hsDynamic(light: 0xC4DDF2, dark: 0x263446).opacity(0.38)
                    let line = Color.hsDynamic(light: 0xD8E8F5, dark: 0x1F2A38).opacity(0.5)
                    for x in stride(from: CGFloat(8), through: size.width, by: 34) {
                        for y in stride(from: CGFloat(10), through: size.height, by: 34) {
                            var circle = Path()
                            circle.addEllipse(in: CGRect(x: x, y: y, width: 2.4, height: 2.4))
                            context.fill(circle, with: .color(dot))

                            var stroke = Path()
                            stroke.move(to: CGPoint(x: x + 11, y: y + 6))
                            stroke.addQuadCurve(to: CGPoint(x: x + 22, y: y + 15), control: CGPoint(x: x + 24, y: y + 4))
                            context.stroke(stroke, with: .color(line), lineWidth: 0.7)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
