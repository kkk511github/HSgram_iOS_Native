import SwiftUI

struct LanguageSettingsView: View {
    @AppStorage("HSPreferredLanguage") private var preferredLanguage = "system"

    private let languages: [(id: String, title: String, subtitle: String)] = [
        ("system", "跟随系统", "使用 iOS 语言顺序"),
        ("en", "English", "English"),
        ("zh-Hans", "简体中文", "Simplified Chinese"),
        ("zh-Hant", "繁体中文", "Traditional Chinese"),
        ("ja", "日本語", "Japanese"),
        ("ko", "한국어", "Korean"),
        ("es", "Español", "Spanish"),
        ("fr", "Français", "French")
    ]

    var body: some View {
        List {
            Section("应用语言") {
                ForEach(languages, id: \.id) { language in
                    Button {
                        preferredLanguage = language.id
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(language.title)
                                    .foregroundStyle(HSTheme.primaryText)
                                Text(language.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                            Spacer()
                            if preferredLanguage == language.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(HSTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("语言")
    }
}
