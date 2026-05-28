import SwiftUI
import UIKit

enum ChatListFilterScope: Hashable, Identifiable {
    case all
    case unread
    case contacts
    case groups
    case archived
    case custom(Int)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .unread:
            return "unread"
        case .contacts:
            return "contacts"
        case .groups:
            return "groups"
        case .archived:
            return "archived"
        case .custom(let id):
            return "custom:\(id)"
        }
    }

    static let baseScopes: [ChatListFilterScope] = [.all, .unread, .contacts, .groups, .archived]

    static func customScopes(from filters: [HSChatListFilter]) -> [ChatListFilterScope] {
        filters
            .filter { !$0.isDefault }
            .map { .custom($0.id) }
    }

    func title(filters: [HSChatListFilter]) -> String {
        switch self {
        case .all:
            return "全部"
        case .unread:
            return "未读"
        case .contacts:
            return "联系人"
        case .groups:
            return "群组"
        case .archived:
            return "归档"
        case .custom(let id):
            return filters.first { $0.id == id }?.displayTitle ?? "文件夹"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "tray.full"
        case .unread:
            return "envelope.badge"
        case .contacts:
            return "person"
        case .groups:
            return "person.3"
        case .archived:
            return "archivebox"
        case .custom:
            return "folder"
        }
    }
}

struct ChatListFilterCounts: Equatable {
    var all = 0
    var unread = 0
    var contacts = 0
    var groups = 0
    var archived = 0
    var custom: [Int: Int] = [:]

    func count(for scope: ChatListFilterScope) -> Int {
        switch scope {
        case .all:
            return all
        case .unread:
            return unread
        case .contacts:
            return contacts
        case .groups:
            return groups
        case .archived:
            return archived
        case .custom(let id):
            return custom[id] ?? 0
        }
    }
}

struct ChatListFilterBar: View {
    @Binding var selection: ChatListFilterScope
    let counts: ChatListFilterCounts
    let filters: [HSChatListFilter]

    private var scopes: [ChatListFilterScope] {
        ChatListFilterScope.baseScopes + ChatListFilterScope.customScopes(from: filters)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(scopes) { scope in
                    Button {
                        selection = scope
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 5) {
                                if case let .custom(id) = scope,
                                   let emoticon = filters.first(where: { $0.id == id })?.emoticon,
                                   !emoticon.isEmpty {
                                    Text(emoticon)
                                }
                                Text(scope.title(filters: filters))
                                if counts.count(for: scope) > 0 {
                                    Text("\(counts.count(for: scope))")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selection == scope ? HSTheme.accent : HSTheme.secondaryText)
                                }
                            }
                            .frame(height: 24)

                            Rectangle()
                                .fill(selection == scope ? HSTheme.accent : .clear)
                                .frame(height: 2)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection == scope ? HSTheme.accent : HSTheme.secondaryText)
                        .frame(minWidth: 76)
                        .padding(.horizontal, 4)
                        .padding(.top, 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(scope.title(filters: filters)) chats")
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 40)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HSTheme.separator.opacity(0.75))
                .frame(height: 1 / UIScreen.main.scale)
        }
    }
}
