import SwiftUI

struct AdvancedToolsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var entitlements: [HSEntitlement] = []
    @State private var tools: [HSAdminTool] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Unified Access") {
                if let errorMessage, entitlements.isEmpty {
                    HSErrorBanner(message: errorMessage)
                }

                ForEach(entitlements) { entitlement in
                    AdvancedEntitlementRow(entitlement: entitlement)
                }

                if entitlements.isEmpty && errorMessage == nil {
                    Text("No advanced access loaded.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Tools") {
                if let errorMessage, !entitlements.isEmpty && tools.isEmpty {
                    HSErrorBanner(message: errorMessage)
                }

                ForEach(tools) { tool in
                    AdvancedToolRow(tool: tool)
                }

                if tools.isEmpty && errorMessage == nil {
                    Text("No advanced tools loaded.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Advanced")
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

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            async let loadedEntitlements = authStore.api.entitlements(session: session)
            async let loadedTools = authStore.api.adminTools(session: session)
            entitlements = try await loadedEntitlements
            tools = try await loadedTools
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdvancedEntitlementRow: View {
    let entitlement: HSEntitlement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(entitlement.title)
                    .font(.headline)
                Text(entitlement.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(entitlement.state)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch entitlement.category {
        case "assets":
            return "face.smiling"
        case "workspace":
            return "tray.full"
        case "privacy":
            return "lock.shield"
        case "support":
            return "person.crop.circle.badge.questionmark"
        default:
            return entitlement.included ? "checkmark.seal" : "seal"
        }
    }

    private var color: Color {
        entitlement.included ? HSTheme.accent : HSTheme.warning
    }
}

private struct AdvancedToolRow: View {
    let tool: HSAdminTool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(tool.title)
                    .font(.headline)
                Text(tool.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(tool.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch tool.category {
        case "circle":
            return "person.3.sequence"
        case "moderation":
            return "shield.lefthalf.filled"
        case "automation":
            return "clock.arrow.circlepath"
        case "assets":
            return "sparkles"
        default:
            return "wrench.adjustable"
        }
    }

    private var color: Color {
        switch tool.status {
        case "available":
            return HSTheme.trust
        case "migrating":
            return HSTheme.circle
        default:
            return HSTheme.warning
        }
    }
}
