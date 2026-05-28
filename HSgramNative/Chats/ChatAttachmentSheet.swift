import SwiftUI

enum ChatAttachmentOption: CaseIterable, Identifiable {
    case gallery
    case camera
    case file
    case location
    case contact
    case poll
    case todo
    case quickReply

    var id: String { key }

    var key: String {
        switch self {
        case .gallery:
            return "gallery"
        case .camera:
            return "camera"
        case .file:
            return "file"
        case .location:
            return "location"
        case .contact:
            return "contact"
        case .poll:
            return "poll"
        case .todo:
            return "todo"
        case .quickReply:
            return "quickReply"
        }
    }

    var title: String {
        switch self {
        case .gallery:
            return "相册"
        case .camera:
            return "相机"
        case .file:
            return "文件"
        case .location:
            return "位置"
        case .contact:
            return "联系人"
        case .poll:
            return "投票"
        case .todo:
            return "待办"
        case .quickReply:
            return "快捷回复"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery:
            return "photo.on.rectangle"
        case .camera:
            return "camera"
        case .file:
            return "doc"
        case .location:
            return "location"
        case .contact:
            return "person.crop.circle"
        case .poll:
            return "chart.bar"
        case .todo:
            return "checklist"
        case .quickReply:
            return "text.bubble"
        }
    }
}

struct ChatAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ChatAttachmentOption) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(ChatAttachmentOption.allCases) { option in
                        Button {
                            dismiss()
                            onSelect(option)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: option.systemImage)
                                    .font(.system(size: 25, weight: .regular))
                                    .foregroundStyle(iconColor(for: option))
                                    .frame(width: 56, height: 56)
                                    .background(iconColor(for: option).opacity(0.12), in: Circle())
                                Text(option.title)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(HSTheme.primaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(minHeight: 32)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104)
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
            }
            .background(HSTheme.grouped)
            .navigationTitle("添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func iconColor(for option: ChatAttachmentOption) -> Color {
        switch option {
        case .gallery:
            return Color(rgb: 0x35c759)
        case .camera:
            return Color(rgb: 0xff2d55)
        case .file:
            return HSTheme.accent
        case .location:
            return Color(rgb: 0xff9500)
        case .contact:
            return Color(rgb: 0x8e63ce)
        case .poll:
            return Color(rgb: 0xff3b30)
        case .todo:
            return Color(rgb: 0x5ac8fa)
        case .quickReply:
            return Color(rgb: 0x00a700)
        }
    }
}
