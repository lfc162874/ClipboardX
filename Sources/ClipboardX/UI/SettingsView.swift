import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var newSensitivePattern = ""
    @State private var newIgnoredSourceApp = ""
    @State private var selectedSection: SettingsSection = .general
    @State private var recordingShortcut: ShortcutTarget?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 700, minHeight: 540)
        .background(SettingsPalette.windowBackground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("设置")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("行为与隐私")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsNavigationButton(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }

            Spacer()

            SettingsStatusBadge(
                title: appState.isAccessibilityTrusted ? "辅助功能已授权" : "辅助功能待授权",
                systemImage: appState.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                color: appState.isAccessibilityTrusted ? SettingsPalette.green : SettingsPalette.orange
            )
        }
        .padding(18)
        .frame(width: 188)
        .background(SettingsPalette.sidebarBackground)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch selectedSection {
                case .general:
                    generalSettings
                case .privacy:
                    privacySettings
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(title: "通用", subtitle: "监听、快捷键和粘贴行为")

            VStack(spacing: 10) {
                SettingsToggleRow(
                    title: "剪贴板监听",
                    subtitle: "暂停后不会继续记录新的剪贴板内容",
                    systemImage: appState.isMonitoring ? "waveform.path.ecg" : "pause.fill",
                    isOn: monitoringBinding
                )

                SettingsToggleRow(
                    title: "自动粘贴",
                    subtitle: "点击历史记录后自动向当前 App 执行 Cmd + V",
                    systemImage: "keyboard",
                    isOn: autoPasteBinding
                )

                SettingsInfoRow(
                    title: appState.isAccessibilityTrusted ? "辅助功能已授权" : "辅助功能未授权",
                    subtitle: appState.isAccessibilityTrusted ? "自动粘贴可以正常工作" : "开启自动粘贴前需要完成 macOS 辅助功能授权",
                    systemImage: appState.isAccessibilityTrusted ? "checkmark.shield.fill" : "lock.open.trianglebadge.exclamationmark",
                    color: appState.isAccessibilityTrusted ? SettingsPalette.green : SettingsPalette.orange
                ) {
                    Button {
                        appState.requestAccessibilityPermission()
                    } label: {
                        Label("授权", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(appState.isAccessibilityTrusted)
                }
            }

            SettingsGroup(title: "快捷键") {
                VStack(spacing: 10) {
                    EditableShortcutRow(
                        title: "打开历史记录",
                        shortcut: appState.historyShortcut,
                        systemImage: "clock.arrow.circlepath",
                        isRecording: recordingShortcut == .history,
                        startAction: { recordingShortcut = .history },
                        resetAction: { appState.resetHistoryShortcut() },
                        captureAction: { shortcut in
                            appState.setHistoryShortcut(shortcut)
                            recordingShortcut = nil
                        },
                        cancelAction: { recordingShortcut = nil }
                    )

                    EditableShortcutRow(
                        title: "截图并固定",
                        shortcut: appState.screenshotShortcut,
                        systemImage: "camera.viewfinder",
                        isRecording: recordingShortcut == .screenshot,
                        startAction: { recordingShortcut = .screenshot },
                        resetAction: { appState.resetScreenshotShortcut() },
                        captureAction: { shortcut in
                            appState.setScreenshotShortcut(shortcut)
                            recordingShortcut = nil
                        },
                        cancelAction: { recordingShortcut = nil }
                    )

                    if let message = appState.hotKeyRegistrationMessage {
                        SettingsInlineStatusRow(
                            message: message,
                            systemImage: "exclamationmark.triangle.fill",
                            color: SettingsPalette.orange
                        )
                    }
                }
            }
        }
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(title: "隐私", subtitle: "过滤敏感内容和忽略来源应用")

            SettingsEditableListSection(
                title: "自定义敏感规则",
                subtitle: "命中规则的文本不会进入历史，也不会通过局域网发送",
                text: $newSensitivePattern,
                placeholder: "新增规则",
                addAction: addSensitivePattern
            ) {
                if appState.customSensitivePatterns.isEmpty {
                    SettingsEmptyRow(title: "暂无自定义规则", systemImage: "shield")
                } else {
                    ForEach(appState.customSensitivePatterns, id: \.self) { pattern in
                        RemovableSettingRow(title: pattern, systemImage: "text.badge.xmark") {
                            appState.removeSensitivePattern(pattern)
                        }
                    }
                }
            }

            Button {
                appState.resetSensitivePatterns()
            } label: {
                Label("重置自定义规则", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(appState.customSensitivePatterns.isEmpty)

            SettingsEditableListSection(
                title: "忽略来源应用",
                subtitle: "来自这些应用的复制内容不会被记录",
                text: $newIgnoredSourceApp,
                placeholder: "应用名称",
                addAction: addIgnoredSourceApp
            ) {
                if appState.ignoredSourceApps.isEmpty {
                    SettingsEmptyRow(title: "暂无忽略应用", systemImage: "app.badge")
                } else {
                    ForEach(appState.ignoredSourceApps, id: \.self) { sourceApp in
                        RemovableSettingRow(title: sourceApp, systemImage: "app.dashed") {
                            appState.removeIgnoredSourceApp(sourceApp)
                        }
                    }
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

    private func addSensitivePattern() {
        appState.addSensitivePattern(newSensitivePattern)
        newSensitivePattern = ""
    }

    private func addIgnoredSourceApp() {
        appState.addIgnoredSourceApp(newIgnoredSourceApp)
        newIgnoredSourceApp = ""
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .privacy:
            return "隐私"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "监听与快捷键"
        case .privacy:
            return "过滤与来源"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .privacy:
            return "hand.raised.fill"
        }
    }
}

private enum ShortcutTarget: Equatable {
    case history
    case screenshot
}

private struct SettingsNavigationButton: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(section.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? SettingsPalette.accent : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                isSelected ? SettingsPalette.accent.opacity(0.12) : SettingsPalette.panelBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? SettingsPalette.accent.opacity(0.28) : SettingsPalette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemImage: systemImage, color: SettingsPalette.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(12)
        .background(SettingsPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsPalette.border, lineWidth: 1)
        }
    }
}

private struct SettingsInfoRow<Action: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: Action

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.action = action()
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemImage: systemImage, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            action
        }
        .padding(12)
        .background(SettingsPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsPalette.border, lineWidth: 1)
        }
    }
}

private struct EditableShortcutRow: View {
    let title: String
    let shortcut: AppShortcut
    let systemImage: String
    let isRecording: Bool
    let startAction: () -> Void
    let resetAction: () -> Void
    let captureAction: (AppShortcut) -> Void
    let cancelAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(systemImage: systemImage, color: SettingsPalette.accent)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            ZStack {
                Button(action: startAction) {
                    Text(isRecording ? "按下组合键" : shortcut.displayString)
                        .font(.callout.monospaced())
                        .foregroundStyle(isRecording ? SettingsPalette.accent : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(minWidth: 152)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(SettingsPalette.inputBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(
                                    isRecording ? SettingsPalette.accent.opacity(0.7) : SettingsPalette.border,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)

                ShortcutRecorderView(
                    isRecording: isRecording,
                    onCapture: captureAction,
                    onCancel: cancelAction
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
            }

            Button(action: resetAction) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("重置快捷键")
            .help("重置快捷键")
        }
        .padding(12)
        .background(SettingsPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsPalette.border, lineWidth: 1)
        }
    }
}

private struct SettingsInlineStatusRow: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (AppShortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isRecording = isRecording

        guard isRecording else {
            if nsView.window?.firstResponder === nsView {
                nsView.window?.makeFirstResponder(nil)
            }
            return
        }

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var onCapture: ((AppShortcut) -> Void)?
    var onCancel: (() -> Void)?
    var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        guard let shortcut = AppShortcut(event: event) else {
            NSSound.beep()
            return
        }

        onCapture?(shortcut)
    }
}

private struct SettingsEditableListSection<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    let placeholder: String
    let addAction: () -> Void
    let content: Content

    init(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        addAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self._text = text
        self.placeholder = placeholder
        self.addAction = addAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SettingsPalette.inputBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(SettingsPalette.border, lineWidth: 1)
                    }
                    .onSubmit(addAction)

                Button(action: addAction) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("添加")
                .help("添加")
            }

            ScrollView {
                VStack(spacing: 8) {
                    content
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 160)
        }
    }
}

private struct RemovableSettingRow: View {
    let title: String
    let systemImage: String
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("删除")
            .help("删除")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(SettingsPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsPalette.border, lineWidth: 1)
        }
    }
}

private struct SettingsEmptyRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(12)
        .background(SettingsPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsPalette.border, lineWidth: 1)
        }
    }
}

private struct SettingsIconBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))

            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 38, height: 38)
    }
}

private struct SettingsStatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
        }
    }
}

private enum SettingsPalette {
    static let accent = Color.accentColor
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let inputBackground = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
}
