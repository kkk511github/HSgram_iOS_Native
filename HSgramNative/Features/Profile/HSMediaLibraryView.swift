import SwiftUI

struct HSMediaLibraryView: View {
    @EnvironmentObject private var data: HSMockChatService
    let conversationID: UUID
    @State private var selectedTab: HSMediaTab = .media

    private var viewModel: HSMediaLibraryViewModel {
        HSMediaLibraryViewModel(messages: data.messages(for: conversationID), selectedTab: selectedTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("媒体类型", selection: $selectedTab) {
                ForEach(HSMediaTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(16)
            if viewModel.items.isEmpty {
                HSEmptyStateView(systemImage: selectedTab.icon, title: "暂无\(selectedTab.title)", message: "这个会话中的\(selectedTab.title)会显示在这里。")
            } else {
                List(viewModel.items) { message in
                    HStack(spacing: 12) {
                        Image(systemName: message.attachment?.previewSystemImage ?? selectedTab.icon).font(.title2.weight(.semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(HSPrototypeTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.attachment?.title ?? message.body).font(.body.weight(.semibold))
                            Text(message.attachment?.subtitle ?? HSDateText.shortTime(message.sentAt)).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(HSPrototypeTheme.background.ignoresSafeArea())
        .navigationTitle("媒体、文件、链接")
        .navigationBarTitleDisplayMode(.inline)
    }
}
