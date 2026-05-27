import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var devices: [HSDeviceSession] = []
    @State private var errorMessage: String?
    @State private var resettingDeviceID: Int64?

    var body: some View {
        List {
            Section {
                if let errorMessage {
                    HSErrorBanner(message: errorMessage)
                }

                ForEach(devices) { device in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(device.deviceModel.isEmpty ? "Unknown Device" : device.deviceModel, systemImage: icon(for: device))
                                .font(.headline)
                            Spacer()
                            if device.current {
                                Text("Current")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(HSTheme.trust)
                            }
                        }

                        Text(deviceSubtitle(device))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(locationSubtitle(device))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        if !device.current {
                            Button(role: .destructive) {
                                Task {
                                    await reset(device)
                                }
                            } label: {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .disabled(resettingDeviceID == device.id)
                        }
                    }
                }

                if devices.isEmpty && errorMessage == nil {
                    Text("No active device sessions.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Devices")
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
            devices = try await authStore.api.devices(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset(_ device: HSDeviceSession) async {
        guard let session = authStore.session else {
            return
        }
        resettingDeviceID = device.id
        defer { resettingDeviceID = nil }
        do {
            _ = try await authStore.api.resetDevice(id: device.id, session: session)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for device: HSDeviceSession) -> String {
        let value = "\(device.platform) \(device.deviceModel)".lowercased()
        if value.contains("ios") || value.contains("iphone") {
            return "iphone"
        }
        if value.contains("ipad") {
            return "ipad"
        }
        if value.contains("mac") || value.contains("windows") || value.contains("desktop") {
            return "desktopcomputer"
        }
        if value.contains("android") {
            return "apps.iphone"
        }
        return "iphone.gen3"
    }

    private func deviceSubtitle(_ device: HSDeviceSession) -> String {
        [device.platform, device.systemVersion, device.appName, device.appVersion]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func locationSubtitle(_ device: HSDeviceSession) -> String {
        let location = [device.region, device.country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if location.isEmpty {
            return device.ip
        }
        if device.ip.isEmpty {
            return location
        }
        return "\(location) · \(device.ip)"
    }
}
