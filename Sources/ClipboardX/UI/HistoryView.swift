import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var keyword = ""
    @State private var selectedType: ClipboardItemType?

    private static let filterTypes: [ClipboardItemType] = [.text, .url, .file, .image]

    private var visibleItems: [ClipboardItem] {
        let searchedItems = appState.search(keyword)
        guard let selectedType else { return searchedItems }
        return searchedItems.filter { $0.type == selectedType }
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
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.toggleMonitoring()
                } label: {
                    Label(appState.isMonitoring ? "暂停" : "继续", systemImage: appState.isMonitoring ? "pause.fill" : "play.fill")
                }
                .help(appState.isMonitoring ? "暂停监听剪贴板" : "继续监听剪贴板")

                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .disabled(appState.items.isEmpty)
                .help("清空全部历史记录")
            }

            TextField("搜索剪贴板历史...", text: $keyword)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Toggle("自动粘贴", isOn: autoPasteBinding)
                    .toggleStyle(.switch)
                    .help("点击历史记录后自动执行 Cmd+V")

                if appState.isAutoPasteEnabled && !appState.isAccessibilityTrusted {
                    Button {
                        appState.requestAccessibilityPermission()
                    } label: {
                        Label("授权辅助功能", systemImage: "exclamationmark.triangle")
                    }
                    .help("自动粘贴需要 macOS 辅助功能权限")
                }

                Spacer()
            }

            Picker("类型", selection: $selectedType) {
                Text("全部").tag(nil as ClipboardItemType?)
                ForEach(Self.filterTypes) { type in
                    Label(type.displayName, systemImage: type.systemImageName)
                        .tag(type as ClipboardItemType?)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(16)
    }

    private var autoPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.isAutoPasteEnabled },
            set: { appState.setAutoPasteEnabled($0) }
        )
    }

    private var statusText: String {
        let countText = "\(appState.items.count) 条记录"
        let monitoringText = appState.isMonitoring ? "正在监听剪贴板" : "监听已暂停"
        let autoPasteText = appState.isAutoPasteEnabled
            ? (appState.isAccessibilityTrusted ? "，自动粘贴已开启" : "，自动粘贴待授权")
            : ""
        let searchText = keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "，匹配 \(visibleItems.count) 条"
        let typeText = selectedType.map { "，\($0.displayName)" } ?? ""

        return "\(monitoringText)，\(countText)\(autoPasteText)\(typeText)\(searchText)"
    }

    private var list: some View {
        Group {
            if visibleItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(appState.items.isEmpty ? "暂无剪贴板历史" : "没有匹配结果")
                        .font(.headline)
                    Text(appState.items.isEmpty ? "复制一段文本、链接、文件或图片后，它会出现在这里。" : "换个关键词或类型试试。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleItems) { item in
                    ClipboardItemRow(
                        item: item,
                        onCopy: { appState.copy(item) },
                        onTogglePinned: { appState.togglePinned(item) },
                        onDelete: { appState.delete(item) }
                    )
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePinned: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onCopy) {
                rowContent
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button(action: onTogglePinned) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isPinned ? "取消置顶" : "置顶")
                .help(item.isPinned ? "取消置顶" : "置顶")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("删除这条记录")
                .help("删除这条记录")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            leadingVisual

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(item.updatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(previewText)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var previewText: String {
        guard item.type == .image else { return item.preview }

        if let image = NSImage(contentsOfFile: item.content) {
            let width = Int(image.size.width.rounded())
            let height = Int(image.size.height.rounded())
            return "PNG 图片，\(width)×\(height)"
        }

        return "图片文件"
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if item.type == .image, let image = NSImage(contentsOfFile: item.content) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                }
        } else {
            Image(systemName: item.type.systemImageName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.isPinned ? .yellow : .secondary)
                .frame(width: 44, height: 44)
        }
    }
}
