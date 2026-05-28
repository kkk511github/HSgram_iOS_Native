import SwiftUI

struct ContactRow: View {
    let contact: HSContact

    var body: some View {
        HStack(spacing: 12) {
            HSClassicAvatar(title: contact.displayName, icon: "person.fill", tint: HSTheme.accent, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(HSTheme.primaryText)
                Text(contact.username.map { "@\($0)" } ?? contact.status)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HSTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch contact.status {
        case "mutual":
            Text("互相关注")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.trust)
        case "pending_received", "pending":
            Text("待处理")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.circle)
        case "pending_sent":
            Text("已发送")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.circle)
        case "blocked":
            Text("已屏蔽")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSTheme.warning)
        default:
            EmptyView()
        }
    }
}
