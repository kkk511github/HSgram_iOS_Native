import SwiftUI

struct HSProfileView: View {
    @EnvironmentObject private var router: HSAppRouter
    @EnvironmentObject private var data: HSMockChatService
    let userID: UUID
    @State private var selectedTab: ProfileTab = .media

    private var viewModel: HSProfileViewModel {
        HSProfileViewModel(user: data.user(id: userID) ?? data.currentUser, conversations: data.conversations)
    }

    private var user: User { viewModel.user }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                actionButtons.padding(.horizontal, 18).padding(.top, 16)
                Picker("资料内容", selection: $selectedTab) {
                    ForEach(ProfileTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                tabContent.padding(.top, 14)
            }
        }
        .background(HSPrototypeTheme.background.ignoresSafeArea())
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HSAvatarView(initials: user.initials, colorHex: user.accentHex, size: 104, isOnline: user.isOnline).padding(.top, 18)
            VStack(spacing: 5) {
                Text(user.displayName).font(.title2.weight(.bold))
                Text("@\(user.username)").font(.subheadline).foregroundStyle(HSPrototypeTheme.accent)
                Text(user.presence.label).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
            }
            Text(user.bio).font(.subheadline).foregroundStyle(HSPrototypeTheme.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 28)
            VStack(spacing: 0) {
                infoRow("邮箱", user.email, icon: "envelope")
                if let phone = user.phone { infoRow("手机号", phone, icon: "phone") }
            }
            .background(HSPrototypeTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    private var actionButtons: some View {
        Button {
            if let conversation = viewModel.conversationForMessage(currentUser: data.currentUser) { router.open(.chat(conversation.id)) }
        } label: {
            Label("发消息", systemImage: "bubble.left.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(HSPrototypeTheme.accent)
    }

    private var tabContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                VStack(spacing: 8) {
                    Image(systemName: selectedTab.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(HSPrototypeTheme.accent)
                    Text(selectedTab.itemTitle(index)).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText).lineLimit(1)
                }
                .frame(height: 94)
                .frame(maxWidth: .infinity)
                .background(HSPrototypeTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }

    private func infoRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(HSPrototypeTheme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(HSPrototypeTheme.secondaryText)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(HSPrototypeTheme.primaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private enum ProfileTab: String, CaseIterable, Identifiable {
    case media, files, links
    var id: String { rawValue }
    var title: String { self == .media ? "媒体" : self == .files ? "文件" : "链接" }
    var icon: String { self == .media ? "photo" : self == .files ? "doc.text" : "link" }
    func itemTitle(_ index: Int) -> String { "\(title) \(index + 1)" }
}
