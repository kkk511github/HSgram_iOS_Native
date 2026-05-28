import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var pushStore: NotificationPushStore
    @State private var settings: HSNotificationSettings?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if settings != nil {
                NotifyScopeEditor(title: "私聊", scope: scopeBinding(\.privateChats))
                NotifyScopeEditor(title: "群组", scope: scopeBinding(\.groups))
                NotifyScopeEditor(title: "频道", scope: scopeBinding(\.channels))
            } else if errorMessage == nil {
                ProgressView()
            }

            Section("设备推送") {
                LabeledContent("系统权限", value: pushStore.authorizationLabel)
                LabeledContent("设备 token", value: pushStore.shortDeviceToken)

                if let message = pushStore.lastStatusMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(HSTheme.secondaryText)
                }
                if let message = pushStore.lastErrorMessage {
                    HSErrorBanner(message: message)
                }

                Button(pushStore.isRegistering ? "注册中" : "允许并注册推送") {
                    Task {
                        await pushStore.requestAuthorizationAndRegister(
                            session: authStore.session,
                            savedAccounts: authStore.savedAccounts
                        )
                    }
                }
                .disabled(pushStore.isRegistering)

                Button("同步当前 token") {
                    Task {
                        await pushStore.syncRegistration(
                            session: authStore.session,
                            savedAccounts: authStore.savedAccounts,
                            userInitiated: true
                        )
                    }
                }
                .disabled(pushStore.isRegistering || pushStore.deviceToken == nil)

                Button("清除角标") {
                    pushStore.clearBadge()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("通知")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
                    Task {
                        await save()
                    }
                }
                .disabled(settings == nil || isSaving)
            }
        }
        .task {
            await refresh()
            await pushStore.refreshAuthorizationStatus()
            await pushStore.syncRegistration(
                session: authStore.session,
                savedAccounts: authStore.savedAccounts
            )
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
            Toggle("启用", isOn: $scope.enabled)
            Toggle("消息预览", isOn: $scope.showPreviews)
            Toggle("静默通知", isOn: $scope.silent)
        }
    }
}
