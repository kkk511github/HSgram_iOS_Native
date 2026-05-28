import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var passcodeStore: PasscodeStore
    @State private var settings: HSPrivacySettings?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }

            if let settings {
                ForEach(settings.items) { item in
                    NavigationLink {
                        PrivacyRuleEditorView(item: item) { updated in
                            applyPrivacyUpdate(updated)
                        }
                    } label: {
                        LabeledContent {
                            Text(item.value)
                                .foregroundStyle(item.status == "active" ? HSTheme.primaryText : HSTheme.secondaryText)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(HSTheme.secondaryText)
                            }
                        }
                    }
                    .disabled(item.status != "active")
                }

                Section("账号隐私") {
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        Label("已屏蔽用户", systemImage: "hand.raised.slash")
                    }
                }

                Section("账号安全") {
                    NavigationLink {
                        LoginPasswordSettingsView()
                    } label: {
                        Label("登录密码", systemImage: "key")
                    }
                }

                Section("本地安全") {
                    NavigationLink {
                        PasscodeSettingsView()
                    } label: {
                        LabeledContent {
                            Text(passcodeStore.statusText)
                                .foregroundStyle(passcodeStore.isEnabled ? HSTheme.trust : HSTheme.secondaryText)
                        } label: {
                            Label("密码锁", systemImage: "lock")
                        }
                    }
                    LabeledContent("自动锁定", value: passcodeStore.autoLockLabel)
                }
            } else if errorMessage == nil {
                ProgressView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("隐私")
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

    private func applyPrivacyUpdate(_ item: HSSettingsItem) {
        guard let settings else {
            return
        }
        let items = settings.items.map { current in
            current.id == item.id ? item : current
        }
        self.settings = HSPrivacySettings(items: items)
    }
}

private struct LoginPasswordSettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var settings: HSLoginPasswordSettings?
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var hint = ""
    @State private var recoveryEmail = ""
    @State private var disablePassword = ""
    @State private var pendingEmailCode = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isLoading = false
    @State private var isSaving = false

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.trust)
            }

            if let settings {
                Section {
                    LabeledContent("登录密码", value: settings.hasPassword ? "已开启" : "未开启")
                    LabeledContent("恢复邮箱", value: settings.hasRecovery ? "已配置" : "未配置")
                    if let hint = settings.hint, !hint.isEmpty {
                        LabeledContent("密码提示", value: hint)
                    }
                    if let loginEmailPattern = settings.loginEmailPattern, !loginEmailPattern.isEmpty {
                        LabeledContent("登录邮箱", value: loginEmailPattern)
                    }
                    if let pendingEmailPattern = settings.pendingEmailPattern, !pendingEmailPattern.isEmpty {
                        LabeledContent("待确认邮箱", value: pendingEmailPattern)
                    }
                } header: {
                    Text("服务端登录密码")
                } footer: {
                    Text("这里修改的是 HSgram 账号登录密码，会影响 iOS、Android、PC 使用同一服务端登录；本机密码锁在“本地安全”里单独设置。")
                }

                if settings.pendingEmailPattern != nil {
                    Section {
                        TextField("邮箱验证码", text: $pendingEmailCode)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numberPad)

                        Button {
                            Task {
                                await confirmEmail()
                            }
                        } label: {
                            Label("确认恢复邮箱", systemImage: "checkmark.seal")
                        }
                        .disabled(isSaving || pendingEmailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            Task {
                                await resendEmail()
                            }
                        } label: {
                            Label("重新发送验证码", systemImage: "arrow.clockwise")
                        }
                        .disabled(isSaving)

                        Button(role: .destructive) {
                            Task {
                                await cancelEmail()
                            }
                        } label: {
                            Label("取消邮箱确认", systemImage: "xmark.circle")
                        }
                        .disabled(isSaving)
                    } header: {
                        Text("恢复邮箱确认")
                    } footer: {
                        Text("服务端返回 EMAIL_UNCONFIRMED 时，需要用邮箱验证码确认后恢复邮箱才会生效。")
                    }
                }

                if settings.hasPassword {
                    Section {
                        SecureField("当前登录密码", text: $currentPassword)
                            .textContentType(.password)
                        SecureField("新登录密码", text: $newPassword)
                            .textContentType(.newPassword)
                        SecureField("再次输入新密码", text: $confirmPassword)
                            .textContentType(.newPassword)
                        TextField("密码提示（可选）", text: $hint)
                            .textInputAutocapitalization(.never)
                        TextField("恢复邮箱（可选）", text: $recoveryEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)

                        Button {
                            Task {
                                await savePassword()
                            }
                        } label: {
                            Label("更新登录密码", systemImage: "key.fill")
                        }
                        .disabled(isSaving)
                    } header: {
                        Text("更改登录密码")
                    }

                    Section {
                        SecureField("当前登录密码", text: $disablePassword)
                            .textContentType(.password)
                        Button(role: .destructive) {
                            Task {
                                await disableLoginPassword()
                            }
                        } label: {
                            Label("关闭登录密码", systemImage: "key.slash")
                        }
                        .disabled(isSaving || disablePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } header: {
                        Text("关闭登录密码")
                    } footer: {
                        Text("关闭后邮箱验证码仍可登录账号。")
                    }
                } else {
                    Section {
                        SecureField("登录密码", text: $newPassword)
                            .textContentType(.newPassword)
                        SecureField("再次输入密码", text: $confirmPassword)
                            .textContentType(.newPassword)
                        TextField("密码提示（可选）", text: $hint)
                            .textInputAutocapitalization(.never)
                        TextField("恢复邮箱（可选）", text: $recoveryEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)

                        Button {
                            Task {
                                await savePassword()
                            }
                        } label: {
                            Label("开启登录密码", systemImage: "key.fill")
                        }
                        .disabled(isSaving)
                    } header: {
                        Text("设置登录密码")
                    }
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("登录密码")
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .disabled(isLoading)
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        isLoading = settings == nil
        do {
            settings = try await authStore.api.loginPasswordSettings(session: session)
            if let settings {
                hint = settings.hint ?? hint
                recoveryEmail = ""
            }
            errorMessage = nil
        } catch {
            errorMessage = loginPasswordErrorMessage(error)
        }
        isLoading = false
    }

    private func savePassword() async {
        guard let session = authStore.session, let settings else {
            return
        }
        let normalizedCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNew.isEmpty else {
            errorMessage = "请输入登录密码。"
            return
        }
        guard normalizedNew == normalizedConfirm else {
            errorMessage = "两次输入的登录密码不一致。"
            return
        }
        guard !settings.hasPassword || !normalizedCurrent.isEmpty else {
            errorMessage = "请输入当前登录密码。"
            return
        }

        await runSavingOperation(successMessage: "登录密码已更新。") {
            try await authStore.api.updateLoginPassword(
                currentPassword: settings.hasPassword ? normalizedCurrent : nil,
                newPassword: normalizedNew,
                hint: hint,
                recoveryEmail: recoveryEmail,
                session: session
            )
        }
        newPassword = ""
        confirmPassword = ""
        currentPassword = ""
    }

    private func disableLoginPassword() async {
        guard let session = authStore.session else {
            return
        }
        let normalizedCurrent = disablePassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCurrent.isEmpty else {
            errorMessage = "请输入当前登录密码。"
            return
        }

        await runSavingOperation(successMessage: "登录密码已关闭。") {
            try await authStore.api.updateLoginPassword(
                currentPassword: normalizedCurrent,
                newPassword: nil,
                hint: nil,
                recoveryEmail: nil,
                session: session
            )
        }
        disablePassword = ""
    }

    private func confirmEmail() async {
        guard let session = authStore.session else {
            return
        }
        let code = pendingEmailCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "请输入邮箱验证码。"
            return
        }

        await runSavingOperation(successMessage: "恢复邮箱已确认。") {
            try await authStore.api.confirmLoginPasswordEmail(code: code, session: session)
        }
        pendingEmailCode = ""
    }

    private func resendEmail() async {
        guard let session = authStore.session else {
            return
        }
        await runSavingOperation(successMessage: "验证码已重新发送。") {
            try await authStore.api.resendLoginPasswordEmail(session: session)
        }
    }

    private func cancelEmail() async {
        guard let session = authStore.session else {
            return
        }
        await runSavingOperation(successMessage: "已取消恢复邮箱确认。") {
            try await authStore.api.cancelLoginPasswordEmail(session: session)
        }
        pendingEmailCode = ""
    }

    private func runSavingOperation(
        successMessage: String,
        operation: () async throws -> HSLoginPasswordSettings
    ) async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        do {
            settings = try await operation()
            statusMessage = successMessage
        } catch let error as HSAPIError where error.serverCode?.hasPrefix("EMAIL_UNCONFIRMED") == true {
            await refresh()
            statusMessage = "已向恢复邮箱发送确认码，请完成邮箱确认。"
        } catch {
            errorMessage = loginPasswordErrorMessage(error)
        }
        isSaving = false
    }

    private func loginPasswordErrorMessage(_ error: Error) -> String {
        guard let apiError = error as? HSAPIError else {
            return error.localizedDescription
        }
        if apiError.serverCode == "PASSWORD_HASH_INVALID" {
            return "当前登录密码不正确。"
        }
        if apiError.serverCode == "PASSWORD_REQUIRED" {
            return "该操作需要当前登录密码。"
        }
        if apiError.serverCode?.hasPrefix("EMAIL_UNCONFIRMED") == true {
            return "恢复邮箱需要验证码确认。"
        }
        if apiError.serverCode == "EMAIL_VERIFY_EXPIRED" {
            return "邮箱验证码已过期，请重新发送。"
        }
        if apiError.serverCode == "CODE_INVALID" {
            return "邮箱验证码不正确。"
        }
        if apiError.serverCode == "EMAIL_INVALID" {
            return "请输入有效恢复邮箱。"
        }
        if apiError.serverCode?.hasPrefix("FLOOD_WAIT") == true {
            return "请求过于频繁，请稍后再试。"
        }
        if apiError.serverCode == "NATIVE_REST_FACADE_NOT_DEPLOYED" {
            return "服务端登录密码必须使用现有 MTProto 协议，请关闭本地 REST 测试桥后重试。"
        }
        return apiError.errorDescription ?? "登录密码操作失败。"
    }
}

private struct PrivacyRuleEditorView: View {
    @EnvironmentObject private var authStore: AuthStore
    let item: HSSettingsItem
    let onUpdated: (HSSettingsItem) -> Void
    @State private var selectedValue: HSPrivacyRuleValue
    @State private var allowExceptions: [HSPrivacyExceptionPeer]
    @State private var disallowExceptions: [HSPrivacyExceptionPeer]
    @State private var pickerMode: PrivacyExceptionMode?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSaving = false

    init(item: HSSettingsItem, onUpdated: @escaping (HSSettingsItem) -> Void) {
        self.item = item
        self.onUpdated = onUpdated
        let stored = item.selection.flatMap(HSPrivacyRuleValue.init(rawValue:))
        let initial = stored?.isBaseRule == true ? stored! : .contacts
        _selectedValue = State(initialValue: initial)
        let exceptions = item.exceptions ?? .empty
        _allowExceptions = State(initialValue: exceptions.allow)
        _disallowExceptions = State(initialValue: exceptions.disallow)
    }

    var body: some View {
        Form {
            if let errorMessage {
                HSErrorBanner(message: errorMessage)
            }
            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HSTheme.trust)
            }

            Section(item.title) {
                Picker("谁可以", selection: $selectedValue) {
                    ForEach(HSPrivacyRuleValue.editableCases) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.inline)

                LabeledContent("当前", value: item.value)
            }

            if selectedValue != .everyone {
                Section {
                    if allowExceptions.isEmpty {
                        Text("没有例外")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    ForEach(allowExceptions) { peer in
                        PrivacyExceptionPeerRow(peer: peer)
                            .swipeActions {
                                Button(role: .destructive) {
                                    allowExceptions.removeAll { $0.id == peer.id }
                                } label: {
                                    Label("移除", systemImage: "minus.circle")
                                }
                            }
                    }
                    Button {
                        pickerMode = .allow
                    } label: {
                        Label("添加例外", systemImage: "plus.circle")
                    }
                } header: {
                    Text("始终允许")
                } footer: {
                    Text("对应旧版 Always Allow：即使基础规则限制，也允许这些联系人、群组或频道。")
                }
            }

            if selectedValue != .nobody {
                Section {
                    if disallowExceptions.isEmpty {
                        Text("没有例外")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    ForEach(disallowExceptions) { peer in
                        PrivacyExceptionPeerRow(peer: peer)
                            .swipeActions {
                                Button(role: .destructive) {
                                    disallowExceptions.removeAll { $0.id == peer.id }
                                } label: {
                                    Label("移除", systemImage: "minus.circle")
                                }
                            }
                    }
                    Button {
                        pickerMode = .disallow
                    } label: {
                        Label("添加例外", systemImage: "plus.circle")
                    }
                } header: {
                    Text("永不允许")
                } footer: {
                    Text("对应旧版 Never Allow：即使基础规则允许，也排除这些联系人、群组或频道。")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle(item.title)
        .sheet(item: $pickerMode) { mode in
            PrivacyExceptionPickerSheet(
                mode: mode,
                excludedPeerIDs: excludedPeerIDs(for: mode)
            ) { peer in
                addException(peer, mode: mode)
            }
            .environmentObject(authStore)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private func save() async {
        guard let session = authStore.session else {
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await authStore.api.updatePrivacySetting(
                id: item.id,
                value: selectedValue,
                exceptions: filteredExceptions,
                session: session
            )
            allowExceptions = updated.exceptions?.allow ?? []
            disallowExceptions = updated.exceptions?.disallow ?? []
            onUpdated(updated)
            statusMessage = "已保存。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var filteredExceptions: HSPrivacyRuleExceptions {
        HSPrivacyRuleExceptions(
            allow: selectedValue == .everyone ? [] : allowExceptions,
            disallow: selectedValue == .nobody ? [] : disallowExceptions
        )
    }

    private func excludedPeerIDs(for mode: PrivacyExceptionMode) -> Set<String> {
        let peers = mode == .allow ? allowExceptions : disallowExceptions
        return Set(peers.map(\.id))
    }

    private func addException(_ peer: HSPrivacyExceptionPeer, mode: PrivacyExceptionMode) {
        switch mode {
        case .allow:
            disallowExceptions.removeAll { $0.id == peer.id }
            guard !allowExceptions.contains(where: { $0.id == peer.id }) else {
                return
            }
            allowExceptions.append(peer)
        case .disallow:
            allowExceptions.removeAll { $0.id == peer.id }
            guard !disallowExceptions.contains(where: { $0.id == peer.id }) else {
                return
            }
            disallowExceptions.append(peer)
        }
    }
}

private enum PrivacyExceptionMode: String, Identifiable {
    case allow
    case disallow

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .allow:
            return "始终允许"
        case .disallow:
            return "永不允许"
        }
    }
}

private struct PrivacyExceptionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    let mode: PrivacyExceptionMode
    let excludedPeerIDs: Set<String>
    let onSelect: (HSPrivacyExceptionPeer) -> Void

    @State private var query = ""
    @State private var contacts: [HSContact] = []
    @State private var dialogs: [HSChat] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                if isSearching {
                    ProgressView()
                }

                Section("联系人") {
                    if selectableContacts.isEmpty {
                        Text("没有可添加的联系人")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                    ForEach(selectableContacts) { peer in
                        Button {
                            onSelect(peer)
                            dismiss()
                        } label: {
                            PrivacyExceptionPeerRow(peer: peer)
                        }
                    }
                }

                if !selectableDialogs.isEmpty || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("群组和频道") {
                        if selectableDialogs.isEmpty {
                            Text("搜索群组或频道名称")
                                .foregroundStyle(HSTheme.secondaryText)
                        }
                        ForEach(selectableDialogs) { peer in
                            Button {
                                onSelect(peer)
                                dismiss()
                            } label: {
                                PrivacyExceptionPeerRow(peer: peer)
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索联系人、群组或频道")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadInitial()
            }
            .onSubmit(of: .search) {
                Task {
                    await search()
                }
            }
            .onChange(of: query) { _ in
                Task {
                    await debouncedSearch()
                }
            }
        }
    }

    private var selectableContacts: [HSPrivacyExceptionPeer] {
        contacts
            .map(HSPrivacyExceptionPeer.user)
            .filter { !excludedPeerIDs.contains($0.id) }
    }

    private var selectableDialogs: [HSPrivacyExceptionPeer] {
        dialogs
            .compactMap(HSPrivacyExceptionPeer.chat)
            .filter { $0.kind != .user && !excludedPeerIDs.contains($0.id) }
    }

    private func loadInitial() async {
        guard contacts.isEmpty, let session = authStore.session else {
            return
        }
        do {
            contacts = try await authStore.api.contacts(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func debouncedSearch() async {
        let current = query
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard current == query else {
            return
        }
        await search()
    }

    private func search() async {
        guard let session = authStore.session else {
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dialogs = []
            await loadInitial()
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await authStore.api.search(query: trimmed, limit: 30, session: session)
            contacts = results.contacts
            dialogs = results.dialogs.filter { $0.id < 0 }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PrivacyExceptionPeerRow: View {
    let peer: HSPrivacyExceptionPeer

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: peer.title, icon: peer.icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.title)
                    .foregroundStyle(HSTheme.primaryText)
                if let subtitle = peer.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(HSTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch peer.kind {
        case .user:
            return HSTheme.accent
        case .group:
            return HSTheme.circle
        case .channel:
            return HSTheme.trust
        }
    }
}
