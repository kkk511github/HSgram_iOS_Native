import SwiftUI

struct HSMediaLibraryView: View {
    @EnvironmentObject private var data: HSMockChatService
    @Environment(\.dismiss) private var dismiss
    let conversationID: UUID
    @State private var selectedTab: HSMediaTab = .media

    private var viewModel: HSMediaLibraryViewModel {
        HSMediaLibraryViewModel(messages: data.messages(for: conversationID), selectedTab: selectedTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSSimplePageHeader(title: "媒体、文件、链接", leadingTitle: nil, trailingTitle: nil, onLeading: { dismiss() }, onTrailing: {})
                .padding(.horizontal, 12)

            Picker("媒体类型", selection: $selectedTab) {
                ForEach(HSMediaTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if viewModel.items.isEmpty {
                HSEmptyStateView(systemImage: selectedTab.icon, title: "暂无\(selectedTab.title)", message: "这个会话中的\(selectedTab.title)会显示在这里。")
            } else {
                List(viewModel.items) { message in
                    HStack(spacing: 12) {
                        Image(systemName: message.attachment?.previewSystemImage ?? selectedTab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(data.themeConfig.inverseTextColor.color)
                            .frame(width: 40, height: 40)
                            .background(data.themeConfig.primaryAccentColor.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.attachment?.title ?? message.body)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(data.themeConfig.primaryTextColor.color)
                            Text(message.attachment?.subtitle ?? HSDateText.shortTime(message.sentAt))
                                .font(.caption)
                                .foregroundStyle(data.themeConfig.secondaryTextColor.color)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(data.themeConfig.groupedBackgroundColor.color)
            }
        }
        .background(data.themeConfig.groupedBackgroundColor.color.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
