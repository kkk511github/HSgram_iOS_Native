import Contacts
import SwiftUI

struct ContactsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var contacts: [HSContact] = []
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isShowingAddContact = false
    @State private var isImportingDeviceContacts = false
    private let deviceContactImportBatchSize = 500

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HSTheme.trust)
                }

                Section("Device Contacts") {
                    Button {
                        Task {
                            await importDeviceContacts()
                        }
                    } label: {
                        Label(isImportingDeviceContacts ? "Importing..." : "Import Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    .disabled(isImportingDeviceContacts)
                }

                Section("请求") {
                    ForEach(pendingReceived) { contact in
                        NavigationLink {
                            ContactProfileView(contact: contact) { updated in
                                applyProfileChange(updated, originalID: contact.id)
                            }
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await decline(contact)
                                }
                            } label: {
                                Label("拒绝", systemImage: "xmark")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                Task {
                                    await accept(contact)
                                }
                            } label: {
                                Label("接受", systemImage: "checkmark")
                            }
                            .tint(HSTheme.trust)
                        }
                    }
                    if pendingReceived.isEmpty {
                        Text("没有待处理的联系人请求。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }

                Section("联系人") {
                    ForEach(visiblePeople) { contact in
                        NavigationLink {
                            ContactProfileView(contact: contact) { updated in
                                applyProfileChange(updated, originalID: contact.id)
                            }
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await delete(contact)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            if contact.status == "blocked" {
                                Button {
                                    Task {
                                        await unblock(contact)
                                    }
                                } label: {
                                    Label("解除屏蔽", systemImage: "hand.raised.slash")
                                }
                                .tint(HSTheme.trust)
                            } else {
                                Button(role: .destructive) {
                                    Task {
                                        await block(contact)
                                    }
                                } label: {
                                    Label("屏蔽", systemImage: "hand.raised")
                                }
                            }
                        }
                    }
                    if visiblePeople.isEmpty {
                        Text("暂无联系人。")
                            .foregroundStyle(HSTheme.secondaryText)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(HSTheme.Chat.listBackground)
            .navigationTitle("联系人")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await importDeviceContacts()
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .disabled(isImportingDeviceContacts)
                    .accessibilityLabel("Import device contacts")

                    Button {
                        isShowingAddContact = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("添加联系人")
                }
            }
            .sheet(isPresented: $isShowingAddContact) {
                AddContactSheet { contact in
                    upsert(contact)
                    statusMessage = "\(contact.displayName) 已添加到联系人。"
                }
                .environmentObject(authStore)
            }
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
        }
    }

    private var pendingReceived: [HSContact] {
        contacts.filter { $0.status == "pending_received" || $0.status == "pending" }
    }

    private var visiblePeople: [HSContact] {
        contacts.filter { contact in
            contact.status != "pending_received" && contact.status != "pending"
        }
    }

    private func refresh() async {
        guard let session = authStore.session else {
            return
        }
        do {
            let loaded = try await authStore.api.contacts(session: session)
            contacts = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func accept(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.acceptContact(userID: contact.id, session: session)
            statusMessage = "\(contact.displayName) 已添加到联系人。"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decline(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.declineContact(userID: contact.id, session: session)
            contacts.removeAll { $0.id == contact.id }
            statusMessage = "已拒绝联系人请求。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.deleteContact(userID: contact.id, session: session)
            contacts.removeAll { $0.id == contact.id }
            statusMessage = "\(contact.displayName) 已移除。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func block(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.blockContact(userID: contact.id, session: session)
            upsert(HSContact(id: contact.id, displayName: contact.displayName, username: contact.username, status: "blocked"))
            statusMessage = "\(contact.displayName) 已屏蔽。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(_ contact: HSContact) async {
        guard let session = authStore.session else {
            return
        }
        do {
            _ = try await authStore.api.unblockContact(userID: contact.id, session: session)
            statusMessage = "\(contact.displayName) 已解除屏蔽。"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importDeviceContacts() async {
        guard let session = authStore.session else {
            return
        }
        guard !isImportingDeviceContacts else {
            return
        }
        isImportingDeviceContacts = true
        defer {
            isImportingDeviceContacts = false
        }
        do {
            let importable = try await loadImportableDeviceContacts()
            guard !importable.isEmpty else {
                statusMessage = "No importable phone numbers found."
                errorMessage = nil
                return
            }
            var importedContacts: [HSContact] = []
            var importedCount = 0
            var popularInviteCount = 0
            var retryContactIDs: [Int64] = []
            for startIndex in stride(from: 0, to: importable.count, by: deviceContactImportBatchSize) {
                let endIndex = min(startIndex + deviceContactImportBatchSize, importable.count)
                let summary = try await authStore.api.importContacts(Array(importable[startIndex..<endIndex]), session: session)
                importedContacts.append(contentsOf: summary.importedContacts)
                importedCount += summary.importedCount
                popularInviteCount += summary.popularInviteCount
                retryContactIDs.append(contentsOf: summary.retryContactIDs)
            }
            importedContacts.forEach(upsert)
            statusMessage = importStatusMessage(
                importedCount: importedCount,
                popularInviteCount: popularInviteCount,
                retryCount: retryContactIDs.count
            )
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadImportableDeviceContacts() async throws -> [HSDeviceContactImport] {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            break
        case .notDetermined:
            let granted = try await requestContactsAccess(store: store)
            guard granted else {
                throw HSAPIError.server(code: "CONTACTS_DENIED", message: "Contacts access was not granted.")
            }
        case .denied, .restricted:
            throw HSAPIError.server(code: "CONTACTS_DENIED", message: "Contacts access is disabled for HSgram.")
        @unknown default:
            throw HSAPIError.server(code: "CONTACTS_DENIED", message: "Contacts access is not available.")
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        var clientID: Int64 = 0
        var seenPhones = Set<String>()
        var importable: [HSDeviceContactImport] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let firstName = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastName = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            for phoneNumber in contact.phoneNumbers {
                let normalizedPhone = normalizedDevicePhone(phoneNumber.value.stringValue)
                guard normalizedPhone.filter(\.isNumber).count >= 5,
                      seenPhones.insert(normalizedPhone).inserted else {
                    continue
                }
                importable.append(HSDeviceContactImport(
                    clientID: clientID,
                    phone: normalizedPhone,
                    firstName: firstName.isEmpty && lastName.isEmpty ? normalizedPhone : firstName,
                    lastName: lastName
                ))
                clientID += 1
            }
        }
        return importable
    }

    private func requestContactsAccess(store: CNContactStore) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func normalizedDevicePhone(_ value: String) -> String {
        var result = ""
        for character in value.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character == "+", result.isEmpty {
                result.append(character)
            } else if character.isNumber {
                result.append(character)
            }
        }
        return result
    }

    private func importStatusMessage(importedCount: Int, popularInviteCount: Int, retryCount: Int) -> String {
        if importedCount > 0 {
            return "Imported \(importedCount) HSgram contact\(importedCount == 1 ? "" : "s")."
        }
        if retryCount > 0 {
            return "Contacts import queued. Please try again later."
        }
        if popularInviteCount > 0 {
            return "No HSgram contacts found yet."
        }
        return "No HSgram contacts found."
    }

    private func upsert(_ contact: HSContact) {
        contacts.removeAll { $0.id == contact.id }
        contacts.insert(contact, at: 0)
    }

    private func applyProfileChange(_ contact: HSContact?, originalID: Int64) {
        if let contact {
            upsert(contact)
        } else {
            contacts.removeAll { $0.id == originalID }
        }
    }
}
