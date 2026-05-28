import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var summary: HSWorkspaceSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                Section("今日工作台") {
                    NavigationLink {
                        ChatListView()
                    } label: {
                        WorkspaceRow(
                            title: "打开聊天",
                            subtitle: "回到聊天列表，继续当前对话。",
                            value: "聊天",
                            systemImage: "bubble.left.and.bubble.right",
                            tint: HSTheme.accent
                        )
                    }

                    NavigationLink {
                        ChatListView()
                    } label: {
                        WorkspaceRow(
                            title: joinRequestCount > 0 ? "群组加入审批" : "新建群组",
                            subtitle: joinRequestCount > 0 ? "处理新的群组加入申请。" : "创建家人、团队或社群群组。",
                            value: joinRequestCount > 0 ? "\(joinRequestCount) 待审" : "创建",
                            systemImage: "person.3.fill",
                            tint: HSTheme.circle
                        )
                    }

                    NavigationLink {
                        ContactsView()
                    } label: {
                        WorkspaceRow(
                            title: "联系人与成员",
                            subtitle: contactRequestCount > 0 ? "有新的联系人或成员关系请求。" : "打开联系人列表和联系人管理。",
                            value: contactRequestCount > 0 ? "\(contactRequestCount)" : "成员",
                            systemImage: "person.crop.circle",
                            tint: HSTheme.accent
                        )
                    }

                    NavigationLink {
                        TrustCenterView()
                    } label: {
                        WorkspaceRow(
                            title: "信任中心",
                            subtitle: trustEventCount > 0 ? "查看设备、举报或安全事件。" : "查看设备、举报、支持和安全控制。",
                            value: trustValue,
                            systemImage: "checkmark.shield.fill",
                            tint: HSTheme.trust
                        )
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        WorkspaceRow(
                            title: "隐私检查",
                            subtitle: "打开隐私、黑名单和可见范围设置。",
                            value: "隐私",
                            systemImage: "lock.shield",
                            tint: HSTheme.circle
                        )
                    }
                }

                let reviewActions = filteredReviewActions
                if !reviewActions.isEmpty {
                    Section("待处理") {
                        ForEach(reviewActions) { action in
                            HStack(spacing: 12) {
                                HSClassicAvatar(title: action.title, icon: "exclamationmark", tint: HSTheme.circle, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(action.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(HSTheme.primaryText)
                                    Text(action.subtitle)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(HSTheme.secondaryText)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(action.badge ?? "\(action.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HSTheme.circle)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("今日")
            .toolbar {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsRemoteNotificationDidArrive)) { _ in
                Task {
                    await refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsRemoteNotificationDidOpen)) { _ in
                Task {
                    await refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hsNativeSyncDidChange)) { _ in
                Task {
                    await refresh()
                }
            }
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await authStore.api.workspaceSummary(session: session)
            summary = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var trustValue: String {
        guard let summary else {
            return "0"
        }
        return summary.counts.trustEvents > 0 ? "\(summary.counts.trustEvents)" : "安全"
    }

    private var contactRequestCount: Int64 {
        summary?.counts.contactRequests ?? 0
    }

    private var joinRequestCount: Int64 {
        summary?.counts.joinRequests ?? 0
    }

    private var trustEventCount: Int64 {
        summary?.counts.trustEvents ?? 0
    }

    private var filteredReviewActions: [HSWorkspaceAction] {
        guard let summary else {
            return []
        }
        return summary.actions.filter { action in
            let route = action.route.lowercased()
            let kind = action.kind.lowercased()
            return !route.contains("circles") && !kind.contains("circle")
        }
    }
}

private struct WorkspaceRow: View {
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: "", icon: systemImage, tint: tint, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(HSTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 4)
    }
}
