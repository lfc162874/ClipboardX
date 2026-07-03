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

    private var pinnedCount: Int {
        appState.items.filter(\.isPinned).count
    }

    private var imageCount: Int {
        appState.items.filter { $0.type == .image }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainContent
        }
        .frame(minWidth: 800, minHeight: 580)
        .background(HistoryPalette.windowBackground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            appIdentity
            quickControls
            filterPanel
            Spacer(minLength: 12)
            statsPanel
        }
        .padding(18)
        .frame(width: 238)
        .background(HistoryPalette.sidebarBackground)
    }

    private var appIdentity: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HistoryPalette.accent.opacity(0.12))
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HistoryPalette.accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("ClipboardX")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(appState.isMonitoring ? "正在监听剪贴板" : "监听已暂停")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var quickControls: some View {
        VStack(spacing: 10) {
            HistoryToggleRow(
                title: appState.isMonitoring ? "监听中" : "已暂停",
                systemImage: appState.isMonitoring ? "waveform.path.ecg" : "pause.fill",
                isOn: monitoringBinding
            )

            HistoryToggleRow(
                title: "自动粘贴",
                systemImage: "keyboard",
                isOn: autoPasteBinding
            )

            if appState.isAutoPasteEnabled && !appState.isAccessibilityTrusted {
                Button {
                    appState.requestAccessibilityPermission()
                } label: {
                    Label("授权辅助功能", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(HistoryPalette.orange)
                .help("自动粘贴需要 macOS 辅助功能权限")
            }

            Button(role: .destructive) {
                appState.clearHistory()
            } label: {
                Label("清空历史", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(appState.items.isEmpty)
            .help("清空全部历史记录")
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                HistoryFilterButton(
                    title: "全部",
                    systemImage: "square.grid.2x2",
                    count: appState.items.count,
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }

                ForEach(Self.filterTypes) { type in
                    HistoryFilterButton(
                        title: type.displayName,
                        systemImage: type.systemImageName,
                        count: appState.items.filter { $0.type == type }.count,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
        }
    }

    private var statsPanel: some View {
        VStack(spacing: 8) {
            HistoryMetricRow(title: "总数", value: "\(appState.items.count)", systemImage: "number")
            HistoryMetricRow(title: "置顶", value: "\(pinnedCount)", systemImage: "pin.fill")
            HistoryMetricRow(title: "图片", value: "\(imageCount)", systemImage: "photo")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            mainHeader
            Divider()
            historyList
        }
    }

    private var mainHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("剪贴板历史")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HistoryStatusChip(
                    title: appState.isMonitoring ? "监听中" : "已暂停",
                    systemImage: appState.isMonitoring ? "circle.fill" : "circle",
                    color: appState.isMonitoring ? HistoryPalette.green : .secondary
                )
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索文本、来源或类型", text: $keyword)
                    .textFieldStyle(.plain)

                if !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(HistoryPalette.inputBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(HistoryPalette.border, lineWidth: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var statusText: String {
        let countText = "\(appState.items.count) 条记录"
        let typeText = selectedType.map { " · \($0.displayName)" } ?? ""
        let searchText = keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : " · 匹配 \(visibleItems.count) 条"
        let pasteText = appState.isAutoPasteEnabled
            ? (appState.isAccessibilityTrusted ? " · 自动粘贴" : " · 自动粘贴待授权")
            : ""

        return "\(countText)\(typeText)\(searchText)\(pasteText)"
    }

    private var historyList: some View {
        Group {
            if visibleItems.isEmpty {
                HistoryEmptyState(
                    title: appState.items.isEmpty ? "暂无历史记录" : "没有匹配结果",
                    subtitle: appState.items.isEmpty ? "复制文本、链接、文件或图片后会出现在这里。" : "换个关键词或类型继续找。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleItems) { item in
                            ClipboardItemRow(
                                item: item,
                                trustedDevices: appState.discoveredDevices.filter(\.isTrusted),
                                onCopy: { appState.copy(item) },
                                onTogglePinned: { appState.togglePinned(item) },
                                onDelete: { appState.delete(item) },
                                onSend: { device in appState.send(item, to: device) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var autoPasteBinding: Binding<Bool> {
        Binding(
            get: { appState.isAutoPasteEnabled },
            set: { appState.setAutoPasteEnabled($0) }
        )
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { appState.isMonitoring },
            set: { isEnabled in
                isEnabled ? appState.startMonitoring() : appState.stopMonitoring()
            }
        )
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let trustedDevices: [SharedDevice]
    let onCopy: () -> Void
    let onTogglePinned: () -> Void
    let onDelete: () -> Void
    let onSend: (SharedDevice) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onCopy) {
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                if item.isLANShareable && !trustedDevices.isEmpty {
                    Menu {
                        ForEach(trustedDevices) { device in
                            Button {
                                onSend(device)
                            } label: {
                                Label(device.name, systemImage: "desktopcomputer")
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane")
                            .frame(width: 26, height: 26)
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("发送到局域网设备")
                    .help("发送到局域网设备")
                }

                Button(action: onTogglePinned) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isPinned ? "取消置顶" : "置顶")
                .help(item.isPinned ? "取消置顶" : "置顶")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("删除这条记录")
                .help("删除这条记录")
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(HistoryPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(HistoryPalette.border, lineWidth: 1)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingVisual

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(item.type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(HistoryPalette.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HistoryPalette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

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
                            .foregroundStyle(HistoryPalette.orange)
                    }
                }

                Text(previewText)
                    .font(.callout)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var previewText: String {
        guard item.type == .image else { return item.preview }

        if let image = NSImage(contentsOfFile: item.content) {
            let width = Int(image.size.width.rounded())
            let height = Int(image.size.height.rounded())
            return "PNG 图片 · \(width) x \(height)"
        }

        return "图片文件"
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if item.type == .image, let image = NSImage(contentsOfFile: item.content) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(HistoryPalette.border, lineWidth: 1)
                }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.isPinned ? HistoryPalette.orange.opacity(0.12) : HistoryPalette.accent.opacity(0.1))

                Image(systemName: item.type.systemImageName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(item.isPinned ? HistoryPalette.orange : HistoryPalette.accent)
            }
            .frame(width: 48, height: 48)
        }
    }
}

private struct HistoryToggleRow: View {
    let title: String
    let systemImage: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.callout)

            Spacer()

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(10)
        .background(HistoryPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(HistoryPalette.border, lineWidth: 1)
        }
    }
}

private struct HistoryFilterButton: View {
    let title: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? HistoryPalette.accent : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? HistoryPalette.accent.opacity(0.12) : HistoryPalette.panelBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? HistoryPalette.accent.opacity(0.28) : HistoryPalette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HistoryPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(HistoryPalette.border, lineWidth: 1)
        }
    }
}

private struct HistoryStatusChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct HistoryEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(HistoryPalette.accent.opacity(0.1))
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(HistoryPalette.accent)
            }
            .frame(width: 68, height: 68)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}

private enum HistoryPalette {
    static let accent = Color.accentColor
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let inputBackground = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
}

private extension ClipboardItem {
    var isLANShareable: Bool {
        type == .text || type == .url || type == .image
    }
}
