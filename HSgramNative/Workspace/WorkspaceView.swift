import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var summary: HSWorkspaceSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HSgram Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HSTheme.accent)
                        Text("Action Inbox")
                            .font(.largeTitle.weight(.bold))
                        Text("Chats, circles, contacts, trust controls, and privacy checks in one workspace.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    if let errorMessage {
                        HSErrorBanner(message: errorMessage)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        HSMetricCard(value: "\(summary?.counts.contactRequests ?? 0)", title: "Contacts", subtitle: "Requests and people", color: HSTheme.accent)
                        HSMetricCard(value: trustValue, title: "Trust Center", subtitle: "Reports, devices, support", color: HSTheme.trust)
                        HSMetricCard(value: "\(summary?.counts.joinRequests ?? 0)", title: "Circles", subtitle: "Join requests and rules", color: HSTheme.circle)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Actions")
                            .font(.headline)

                        NavigationLink {
                            ChatListView()
                        } label: {
                            HSActionRow(title: "Chats", subtitle: "Open recent conversations.", badge: "Open", systemImage: "bubble.left.and.bubble.right", color: HSTheme.accent) {}
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CirclesView()
                        } label: {
                            HSActionRow(title: "New Circle", subtitle: "Create or manage communication circles.", badge: "Circle", systemImage: "person.3.sequence", color: HSTheme.circle) {}
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ContactsView()
                        } label: {
                            HSActionRow(title: "People & Contacts", subtitle: "Review friends and incoming requests.", badge: "People", systemImage: "person.crop.circle.badge.plus", color: HSTheme.accent) {}
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TrustCenterView()
                        } label: {
                            HSActionRow(title: "Trust Center", subtitle: "Review devices, reports, support, and safety controls.", badge: "Safety", systemImage: "checkmark.shield", color: HSTheme.trust) {}
                        }
                        .buttonStyle(.plain)
                    }

                    if let summary, !summary.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Needs Review")
                                .font(.headline)
                            ForEach(summary.actions) { action in
                                HSCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(action.title)
                                                .font(.headline)
                                            Text(action.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(action.badge ?? "\(action.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(HSTheme.circle)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(HSTheme.grouped)
            .navigationTitle("Today")
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
        return summary.counts.trustEvents > 0 ? "\(summary.counts.trustEvents)" : "Safe"
    }
}
