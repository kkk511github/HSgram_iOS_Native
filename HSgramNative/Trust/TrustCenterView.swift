import SwiftUI

struct TrustCenterView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var items: [HSTrustItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trust Center")
                            .font(.largeTitle.weight(.bold))
                        Text("Review privacy, reporting, device, support, and account controls.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Review") {
                    if let errorMessage {
                        HSErrorBanner(message: errorMessage)
                    }
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: item))
                                .foregroundStyle(color(for: item))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if items.isEmpty && errorMessage == nil {
                        Text("No trust review items.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Account") {
                    Label("Privacy and Security", systemImage: "hand.raised")
                    Label("Notifications", systemImage: "bell")
                    Label("Data and Storage", systemImage: "externaldrive")
                    Label("Support", systemImage: "questionmark.circle")
                    Label("Delete Account", systemImage: "trash")
                        .foregroundStyle(HSTheme.warning)
                }
            }
            .navigationTitle("Trust")
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
