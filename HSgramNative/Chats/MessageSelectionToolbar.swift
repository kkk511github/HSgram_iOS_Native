import SwiftUI

struct MessageSelectionToolbar: View {
    let selectedCount: Int
    let canCopy: Bool
    let onCancel: () -> Void
    let onCopy: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("取消选择")

            Text("已选 \(selectedCount) 条")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 34, height: 34)
            }
            .disabled(!canCopy)
            .accessibilityLabel("复制选中消息")

            Button {
                onForward()
            } label: {
                Image(systemName: "arrowshape.turn.up.right")
                    .frame(width: 34, height: 34)
            }
            .disabled(selectedCount == 0)
            .accessibilityLabel("转发选中消息")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .disabled(selectedCount == 0)
            .accessibilityLabel("删除选中消息")
        }
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
