import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.preview.isEmpty ? "Untitled item" : item.preview)
                .font(.body)
                .lineLimit(2)

            Text(item.kind.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
