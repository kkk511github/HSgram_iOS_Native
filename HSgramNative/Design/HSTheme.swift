import SwiftUI

enum HSTheme {
    static let accent = Color(red: 0.08, green: 0.45, blue: 0.88)
    static let trust = Color(red: 0.10, green: 0.58, blue: 0.34)
    static let circle = Color(red: 0.69, green: 0.33, blue: 0.10)
    static let warning = Color(red: 0.78, green: 0.23, blue: 0.18)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let grouped = Color(.systemGroupedBackground)
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
            .background(HSTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .background(HSTheme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .background(HSTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
