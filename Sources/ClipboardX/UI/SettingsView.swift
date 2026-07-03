import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var newSensitivePattern = ""
    @State private var newIgnoredSourceApp = ""

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "switch.2")
                }

            privacySettings
                .tabItem {
                    Label("隐私", systemImage: "hand.raised")
                }
        }
        .padding(18)
        .frame(width: 560, height: 460)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(title: "通用", subtitle: "监听、快捷键和粘贴行为")

            Toggle("自动粘贴", isOn: autoPasteBinding)
                .toggleStyle(.switch)
                .help("点击历史记录后自动执行 Cmd+V")

            HStack(spacing: 8) {
                Label(
                    appState.isAccessibilityTrusted ? "辅助功能已授权" : "辅助功能未授权",
                    systemImage: appState.isAccessibilityTrusted ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .foregroundStyle(appState.isAccessibilityTrusted ? .green : .orange)

                Spacer()

                Button {
                    appState.requestAccessibilityPermission()
                } label: {
                    Label("授权", systemImage: "lock.open")
                }
                .disabled(appState.isAccessibilityTrusted)
            }

            Divider()

            Toggle("剪贴板监听", isOn: monitoringBinding)
                .toggleStyle(.switch)

            Spacer()
        }
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(title: "隐私", subtitle: "过滤敏感内容和忽略来源应用")

            SettingsListSection(
                title: "自定义敏感规则",
                text: $newSensitivePattern,
                placeholder: "新增规则",
                addAction: addSensitivePattern
            ) {
                ForEach(appState.customSensitivePatterns, id: \.self) { pattern in
                    RemovableSettingRow(title: pattern) {
                        appState.removeSensitivePattern(pattern)
                    }
                }

                if appState.customSensitivePatterns.isEmpty {
                    EmptySettingsRow(title: "暂无自定义规则")
                }
            }

            Button {
                appState.resetSensitivePatterns()
            } label: {
                Label("重置自定义规则", systemImage: "arrow.counterclockwise")
            }
            .disabled(appState.customSensitivePatterns.isEmpty)

            Divider()

            SettingsListSection(
                title: "忽略来源应用",
                text: $newIgnoredSourceApp,
                placeholder: "应用名称",
                addAction: addIgnoredSourceApp
            ) {
                ForEach(appState.ignoredSourceApps, id: \.self) { sourceApp in
                    RemovableSettingRow(title: sourceApp) {
                        appState.removeIgnoredSourceApp(sourceApp)
                    }
                }

                if appState.ignoredSourceApps.isEmpty {
                    EmptySettingsRow(title: "暂无忽略应用")
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

private struct SettingsListSection<Content: View>: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let addAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addAction)

                Button(action: addAction) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("添加")
            }

            ScrollView {
                VStack(spacing: 0) {
                    content
                }
            }
            .frame(maxHeight: 116)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }
}

private struct RemovableSettingRow: View {
    let title: String
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)

            Spacer()

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("删除")
            .help("删除")
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct EmptySettingsRow: View {
    let title: String

    var body: some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
