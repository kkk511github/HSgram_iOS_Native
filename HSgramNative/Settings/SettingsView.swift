import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        NavigationStack {
            List {
                if let session = authStore.session {
                    Section {
                        NavigationLink {
                            ProfileSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(HSTheme.accent.opacity(0.16))
                                    .overlay {
                                        Text(String(session.displayName.prefix(1)))
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(HSTheme.accent)
                                    }
                                    .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.displayName)
                                        .font(.headline)
                                    Text(session.email)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("HSgram Advanced") {
                    NavigationLink {
                        AdvancedToolsView()
                    } label: {
                        Label("Advanced", systemImage: "sparkles")
                    }
                }

                Section("Trust & Communication Hub") {
                    NavigationLink {
                        TrustCenterView()
                    } label: {
                        Label("Trust Center", systemImage: "checkmark.shield")
                    }
                    NavigationLink {
                        DevicesView()
                    } label: {
                        Label("Devices", systemImage: "iphone.gen3")
                    }
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy and Security", systemImage: "hand.raised")
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    NavigationLink {
                        DataStorageSettingsView()
                    } label: {
                        Label("Data and Storage", systemImage: "externaldrive")
                    }
                    Label("Language", systemImage: "globe")
                    Label("Support", systemImage: "questionmark.circle")
                }

                Section("Developer Bridge") {
                    LabeledContent("API Host", value: "https://hsgram.cloud")
                    LabeledContent("Auth", value: "Email only")
                    LabeledContent("Interop", value: "Shared HSgram server")
                }

                Section {
                    Button(role: .destructive) {
                        authStore.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var about = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            Section("Account") {
                TextField("Display Name", text: $displayName)
                    .textInputAutocapitalization(.words)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("Email", value: email)
            }

            Section("Bio") {
                TextField("About", text: $about)
            }
        }
        .navigationTitle("Personal Info")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving" : "Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard let session = authStore.session, !isLoading else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await authStore.api.accountProfile(session: session)
            displayName = profile.displayName
            username = profile.username ?? ""
            about = profile.about
            email = profile.email
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let session = authStore.session else {
            return
        }
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            errorMessage = "Display name is required."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = try await authStore.api.updateAccountProfile(
                displayName: normalizedName,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                session: session
            )
            displayName = profile.displayName
            username = profile.username ?? ""
            about = profile.about
            email = profile.email
            authStore.replaceSessionProfile(displayName: profile.displayName, email: profile.email)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PrivacySettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var settings: HSPrivacySettings?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if let settings {
                ForEach(settings.items) { item in
                    LabeledContent {
                        Text(item.value)
                            .foregroundStyle(item.status == "active" ? .primary : .secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if errorMessage == nil {
                ProgressView()
            }
        }
        .navigationTitle("Privacy")
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
        do {
            settings = try await authStore.api.privacySettings(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var settings: HSNotificationSettings?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if settings != nil {
                NotifyScopeEditor(title: "Private Chats", scope: scopeBinding(\.privateChats))
                NotifyScopeEditor(title: "Groups", scope: scopeBinding(\.groups))
                NotifyScopeEditor(title: "Channels", scope: scopeBinding(\.channels))
            } else if errorMessage == nil {
                ProgressView()
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving" : "Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(settings == nil || isSaving)
            }
        }
        .task {
            await refresh()
        }
    }

    private func scopeBinding(_ keyPath: WritableKeyPath<HSNotificationSettings, HSNotifyScopeSettings>) -> Binding<HSNotifyScopeSettings> {
        Binding {
            settings?[keyPath: keyPath] ?? .enabledDefault
        } set: { value in
            settings?[keyPath: keyPath] = value
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            settings = try await authStore.api.notificationSettings(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let session = authStore.session, let settings else {
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            self.settings = try await authStore.api.updateNotificationSettings(settings, session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NotifyScopeEditor: View {
    let title: String
    @Binding var scope: HSNotifyScopeSettings

    var body: some View {
        Section(title) {
            Toggle("Enabled", isOn: $scope.enabled)
            Toggle("Message Preview", isOn: $scope.showPreviews)
            Toggle("Silent Delivery", isOn: $scope.silent)
        }
    }
}

private struct DataStorageSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var settings: HSStorageSettings?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if let settings {
                Section("Usage") {
                    LabeledContent("Media", value: byteText(settings.mediaBytes))
                    LabeledContent("Documents", value: byteText(settings.documentBytes))
                    LabeledContent("Cache", value: byteText(settings.cacheBytes))
                    LabeledContent("Other", value: byteText(settings.otherBytes))
                }

                Section("Assets") {
                    LabeledContent("Installed Stickers", value: "\(settings.installedStickerSets)")
                    LabeledContent("Featured Stickers", value: "\(settings.featuredStickerSets)")
                    LabeledContent("Reactions", value: "\(settings.availableReactions)")
                }

                Section("Auto Download") {
                    LabeledContent("Wi-Fi", value: settings.autoDownloadWiFi ? "On" : "Off")
                    LabeledContent("Cellular", value: settings.autoDownloadCellular ? "On" : "Off")
                }
            } else if errorMessage == nil {
                ProgressView()
            }
        }
        .navigationTitle("Data & Storage")
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
        do {
            settings = try await authStore.api.storageSettings(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
