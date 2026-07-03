import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var keyword = ""

    private var visibleItems: [ClipboardItem] {
        appState.search(keyword)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ClipboardX")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(appState.isMonitoring ? "正在监听剪贴板" : "监听已暂停")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(appState.isMonitoring ? "暂停" : "继续") {
                    appState.toggleMonitoring()
                }

                Button("清空") {
                    appState.clearHistory()
                }
            }

            TextField("搜索剪贴板历史...", text: $keyword)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
    }

    private var list: some View {
        Group {
            if visibleItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无剪贴板历史")
                        .font(.headline)
                    Text("复制一段文本后，它会出现在这里。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleItems) { item in
                    ClipboardItemRow(item: item) {
                        appState.copy(item)
                    }
                }
            }
        }
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.type.rawValue.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    Text(item.updatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.preview)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
