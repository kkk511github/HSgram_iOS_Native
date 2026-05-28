import SwiftUI

struct HSContactsView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    @State private var query = ""
    @State private var contactStatus: String?

    private var filteredContacts: [Contact] {
        data.contacts.filter { query.isEmpty || $0.user.displayName.localizedCaseInsensitiveContains(query) || $0.user.username.localizedCaseInsensitiveContains(query) }
    }

    private var grouped: [(String, [Contact])] {
        Dictionary(grouping: filteredContacts, by: \.sectionTitle)
            .map { ($0.key, $0.value.sorted { $0.user.displayName < $1.user.displayName }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSNavigationBar(title: "联系人")
            List {
                Section {
                    HSSearchBar(text: $query, placeholder: "搜索联系人")
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(HSPrototypeTheme.background)
                }
                Section {
                    actionRow(icon: "person.badge.plus", title: "添加好友", color: HSPrototypeTheme.accent) {
                        query = ""
                        contactStatus = "已打开添加好友入口，可通过邮箱或手机号查找。"
                    }
                    actionRow(icon: "envelope.badge", title: "好友申请", color: HSPrototypeTheme.orange) {
                        contactStatus = "当前没有新的好友申请。"
                    }
                    actionRow(icon: "person.crop.circle.badge.checkmark", title: "通讯录同步", color: HSPrototypeTheme.success) {
                        contactStatus = "通讯录已同步，发现 \(data.contacts.count) 位联系人。"
                    }
                    if let contactStatus {
                        Text(contactStatus)
                            .font(.caption)
                            .foregroundStyle(HSPrototypeTheme.secondaryText)
                            .padding(.vertical, 3)
                    }
                }
                if grouped.isEmpty {
                    Section {
                        HSEmptyStateView(systemImage: "person.2", title: "没有找到联系人", message: "换个关键词试试，或通过邮箱/手机号添加好友。")
                            .frame(height: 330)
                            .listRowBackground(HSPrototypeTheme.background)
                    }
                } else {
                    ForEach(grouped, id: \.0) { section, contacts in
                        Section(section) {
                            ForEach(contacts) { contact in
                                Button { router.open(.profile(contact.user.id)) } label: {
                                    HStack(spacing: 12) {
                                        HSAvatarView(initials: contact.user.initials, colorHex: contact.user.accentHex, size: 44, isOnline: contact.user.isOnline)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(contact.user.displayName).font(.body.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
                                            Text(contact.note.isEmpty ? "@\(contact.user.username)" : contact.note).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                                        }
                                        Spacer()
                                        if contact.isFavorite { Image(systemName: "star.fill").foregroundStyle(HSPrototypeTheme.orange) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(HSPrototypeTheme.background)
        }
        .background(HSPrototypeTheme.background.ignoresSafeArea())
    }

    private func actionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .foregroundStyle(HSPrototypeTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HSPrototypeTheme.tertiaryText)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
