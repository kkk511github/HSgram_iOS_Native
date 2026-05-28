import SwiftUI

struct SupportSettingsView: View {
    var body: some View {
        List {
            Section("帮助") {
                Link(destination: URL(string: "https://hsgram.cloud/support/")!) {
                    Label("HSgram FAQ", systemImage: "safari")
                }
                Link(destination: URL(string: "mailto:support@hsgram.cloud")!) {
                    Label("联系支持", systemImage: "envelope")
                }
            }

            Section("账号") {
                NavigationLink {
                    DevicesView()
                } label: {
                    Label("活跃设备", systemImage: "iphone.gen3")
                }
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    Label("隐私与安全", systemImage: "hand.raised")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSTheme.grouped)
        .navigationTitle("帮助")
    }
}
