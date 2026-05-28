import SwiftUI

struct TrustCenterView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var items: [HSTrustItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("信任中心")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(HSTheme.primaryText)
                        Text("查看隐私、设备、支持和账号安全。")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    .padding(.vertical, 8)
                }

                Section("检查") {
                    if let errorMessage {
                        HSErrorBanner(message: errorMessage)
                    }
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            HSClassicAvatar(title: "", icon: icon(for: item), tint: color(for: item), size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(HSTheme.primaryText)
                                Text(item.subtitle)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if items.isEmpty && errorMessage == nil {
                        Text("暂无需要检查的项目。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }

                Section("账号") {
                    Label("隐私与安全", systemImage: "hand.raised")
                    Label("通知", systemImage: "bell")
                    Label("数据与存储", systemImage: "externaldrive")
                    Label("帮助", systemImage: "questionmark.circle")
                    Label("删除账号", systemImage: "trash")
                        .foregroundStyle(HSTheme.warning)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HSTheme.grouped)
            .navigationTitle("信任")
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let loaded = try await authStore.api.trustItems(session: session)
            items = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for item: HSTrustItem) -> String {
        switch item.id {
        case "devices":
            return "iphone.gen3"
        case "reports":
            return "exclamationmark.bubble"
        case "privacy":
            return "lock.shield"
        default:
            return "checkmark.shield"
        }
    }

    private func color(for item: HSTrustItem) -> Color {
        item.severity == "attention" ? HSTheme.warning : HSTheme.trust
    }
}
