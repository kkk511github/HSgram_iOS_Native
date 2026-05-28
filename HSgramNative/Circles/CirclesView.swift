import SwiftUI

struct CirclesView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var circles: [HSCircle] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                if circles.isEmpty && errorMessage == nil {
                    Text("No circles yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(circles) { circle in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(circle.title)
                                        .font(.headline)
                                    Text("\(circle.memberCount) members · \(circle.role)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if circle.pendingRequests > 0 {
                                    Text("\(circle.pendingRequests) pending")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(HSTheme.circle)
                                }
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                                NavigationLink {
                                    ChatThreadView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Open Chat", systemImage: "bubble.left.and.bubble.right")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Manage", systemImage: "info.circle")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Rules", systemImage: "doc.text")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Invite Links", systemImage: "link")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Members", systemImage: "person.2")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Permissions", systemImage: "lock.shield")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Admins", systemImage: "star")
                                }
                                NavigationLink {
                                    SupergroupManageView(chat: circleChat(for: circle))
                                } label: {
                                    CircleToolLabel(title: "Recent Actions", systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Circles")
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
            let loaded = try await authStore.api.circles(session: session)
            circles = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func circleChat(for circle: HSCircle) -> HSChat {
        HSChat(
            id: circle.id,
            title: circle.title,
            subtitle: "\(circle.memberCount) members · \(circle.role)",
            unreadCount: 0,
            isCircle: true,
            peerKind: .chat,
            updatedAt: nil
        )
    }
}

private struct CircleToolLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
    }
}
