import SwiftUI

struct ProfileSettingsView: View {
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

            Section("账号") {
                TextField("显示名称", text: $displayName)
                    .textInputAutocapitalization(.words)
                TextField("用户名", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                LabeledContent("邮箱", value: email)
            }

            Section("简介") {
                TextField("关于", text: $about)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("个人资料")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
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
            errorMessage = "请输入显示名称。"
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
