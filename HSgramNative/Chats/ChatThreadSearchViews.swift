import SwiftUI

struct ChatSearchResult: Identifiable, Hashable {
    let messageID: Int64
    let authorName: String
    let text: String
    let kind: String?
    let sentAt: Date

    var id: Int64 {
        messageID
    }

    init(message: HSSearchMessage) {
        messageID = message.id
        authorName = message.authorName
        text = message.text
        kind = message.kind
        sentAt = message.sentAt
    }
}

enum ThreadSearchNavigationDirection {
    case earlier
    case later
}

struct ChatSearchInputBar: View {
    @Binding var query: String
    let isSearching: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(HSTheme.secondaryText)
                TextField("搜索", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if isSearching {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())

            Button("取消") {
                onCancel()
            }
            .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

struct ChatSearchNavigationPanel: View {
    let currentDisplayIndex: Int?
    let totalCount: Int
    let didSearch: Bool
    let canOpenResults: Bool
    let canNavigateEarlier: Bool
    let canNavigateLater: Bool
    let onEarlier: () -> Void
    let onLater: () -> Void
    let onOpenResults: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button {
                onOpenResults()
            } label: {
                Image(systemName: "list.bullet")
            }
            .disabled(!canOpenResults)

            Spacer()

            Text(resultsTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(totalCount == 0 ? .secondary : .primary)

            Spacer()

            Button {
                onEarlier()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!canNavigateEarlier)

            Button {
                onLater()
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!canNavigateLater)
        }
        .font(.headline)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var resultsTitle: String {
        if let currentDisplayIndex, totalCount > 0 {
            return "\(currentDisplayIndex) of \(totalCount)"
        }
        return didSearch ? "没有结果" : "搜索消息"
    }
}

struct ChatSearchResultsList: View {
    @Environment(\.dismiss) private var dismiss

    let query: String
    let results: [ChatSearchResult]
    let currentMessageID: Int64?
    let onSelect: (ChatSearchResult) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("结果") {
                    if results.isEmpty {
                        Text("没有找到 “\(query)” 的结果。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    ForEach(results.reversed()) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            ChatSearchResultRow(result: result, isCurrent: result.messageID == currentMessageID)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ChatSearchResultRow: View {
    let result: ChatSearchResult
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: "", icon: result.kind == "media" ? "photo.fill" : "text.bubble.fill", tint: HSTheme.accent, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.authorName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HSTheme.primaryText)
                    Spacer()
                    Text(result.sentAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(HSTheme.secondaryText)
                }
                Text(result.text.isEmpty ? "消息 #\(result.messageID)" : result.text)
                    .font(.footnote)
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(2)
            }

            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HSTheme.trust)
            }
        }
    }
}
