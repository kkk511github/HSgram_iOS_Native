import SwiftUI

struct HSMediaLibraryView: View {
    @EnvironmentObject private var data: HSMockChatService
    let conversationID: UUID
    @State private var selectedTab: MediaTab = .media

    private var items: [Message] {
        data.messages(for: conversationID).filter { message in
            switch selectedTab {
            case .media: return message.kind == .image
            case .files: return message.kind == .file || message.attachment?.kind == .file
            case .links: return message.body.contains("http") || message.attachment?.kind == .link
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("媒体类型", selection: $selectedTab) {
                ForEach(MediaTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(16)
            if items.isEmpty {
                HSEmptyStateView(systemImage: selectedTab.icon, title: "暂无\(selectedTab.title)", message: "这个会话中的\(selectedTab.title)会显示在这里。")
            } else {
                List(items) { message in
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

private enum MediaTab: String, CaseIterable, Identifiable {
    case media, files, links
    var id: String { rawValue }
    var title: String { self == .media ? "媒体" : self == .files ? "文件" : "链接" }
    var icon: String { self == .media ? "photo.on.rectangle" : self == .files ? "doc.text" : "link" }
}
