import AppKit
import SwiftUI

struct LANSharingView: View {
    @ObservedObject var appState: AppState
    @State private var deviceNameDraft = ""

    private var trustedDevices: [SharedDevice] {
        appState.discoveredDevices.filter(\.isTrusted)
    }

    private var onlineSummary: String {
        if !appState.isLANSharingEnabled {
            return "共享已关闭"
        }

        let deviceCount = appState.discoveredDevices.count
        let pendingCount = appState.incomingClipboardRequests.count
        return "\(deviceCount) 台设备在线 · \(pendingCount) 条待接收"
    }

    private var canSaveDeviceName: Bool {
        let normalized = deviceNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty && normalized != appState.localDeviceName
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainPane
        }
        .frame(minWidth: 800, minHeight: 580)
        .background(LANPalette.windowBackground)
        .onAppear {
            deviceNameDraft = appState.localDeviceName
        }
        .onChange(of: appState.localDeviceName) { name in
            deviceNameDraft = name
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sidebarHeader

            VStack(alignment: .leading, spacing: 12) {
                LANPreferenceToggle(
                    title: "局域网共享",
                    systemImage: "power",
                    isOn: lanSharingBinding
                )

                deviceNameEditor

                LANPreferenceToggle(
                    title: "确认后复制",
                    systemImage: "doc.on.clipboard",
                    isOn: autoCopyReceivedBinding,
                    isDisabled: !appState.isLANSharingEnabled
                )
            }

            Divider()

            metrics

            Spacer(minLength: 12)

            LANStatusChip(
                title: appState.isLANSharingEnabled ? "正在广播" : "未广播",
                systemImage: appState.isLANSharingEnabled ? "antenna.radiowaves.left.and.right" : "moon",
                tone: appState.isLANSharingEnabled ? .green : .secondary
            )
        }
        .padding(18)
        .frame(width: 252)
        .background(LANPalette.sidebarBackground)
    }

    private var sidebarHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(appState.isLANSharingEnabled ? LANPalette.green.opacity(0.16) : LANPalette.border.opacity(0.45))
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appState.isLANSharingEnabled ? LANPalette.green : .secondary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("局域网共享")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(onlineSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var deviceNameEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("本机名称", systemImage: "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("设备名", text: $deviceNameDraft)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(LANPalette.inputBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(LANPalette.border, lineWidth: 1)
                    }
                    .onSubmit(saveDeviceName)

                Button(action: saveDeviceName) {
                    Image(systemName: "checkmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canSaveDeviceName)
                .accessibilityLabel("保存本机名称")
                .help("保存本机名称")
            }
        }
    }

    private var metrics: some View {
        VStack(spacing: 8) {
            LANMetricRow(
                title: "待接收",
                value: "\(appState.incomingClipboardRequests.count)",
                systemImage: "tray.and.arrow.down.fill",
                tone: appState.incomingClipboardRequests.isEmpty ? .secondary : .orange
            )

            LANMetricRow(
                title: "已信任",
                value: "\(trustedDevices.count)",
                systemImage: "checkmark.shield.fill",
                tone: trustedDevices.isEmpty ? .secondary : .green
            )

            LANMetricRow(
                title: "发现设备",
                value: "\(appState.discoveredDevices.count)",
                systemImage: "person.2.fill",
                tone: appState.discoveredDevices.isEmpty ? .secondary : .accent
            )
        }
    }

    private var mainPane: some View {
        VStack(spacing: 0) {
            mainHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    messageSection
                    incomingClipboardSection
                    pairingSection
                    discoveredDevicesSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var mainHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("共享中心")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(appState.localDeviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            LANStatusChip(
                title: appState.isLANSharingEnabled ? "在线" : "离线",
                systemImage: appState.isLANSharingEnabled ? "circle.fill" : "circle",
                tone: appState.isLANSharingEnabled ? .green : .secondary
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var messageSection: some View {
        if let message = appState.lanSharingMessage {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: "info.circle")
                    .foregroundStyle(LANPalette.accent)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(LANPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LANPalette.accent.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var incomingClipboardSection: some View {
        LANSection(
            title: "待接收",
            subtitle: "\(appState.incomingClipboardRequests.count)",
            systemImage: "tray.and.arrow.down.fill"
        ) {
            if appState.incomingClipboardRequests.isEmpty {
                LANEmptyState(
                    title: "暂无待接收内容",
                    systemImage: "tray"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.incomingClipboardRequests) { request in
                        IncomingClipboardRequestRow(
                            request: request,
                            onAccept: { appState.acceptIncomingClipboardRequest(request) },
                            onReject: { appState.rejectIncomingClipboardRequest(request) }
                        )
                    }
                }
            }
        }
    }

    private var pairingSection: some View {
        LANSection(
            title: "配对请求",
            subtitle: "\(appState.pairingRequests.count)",
            systemImage: "person.crop.circle.badge.questionmark"
        ) {
            if appState.pairingRequests.isEmpty {
                LANEmptyState(
                    title: "暂无配对请求",
                    systemImage: "person.crop.circle.badge.checkmark"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.pairingRequests) { request in
                        PairingRequestRow(
                            request: request,
                            onTrust: { appState.trustDevice(request.device) }
                        )
                    }
                }
            }
        }
    }

    private var discoveredDevicesSection: some View {
        LANSection(
            title: "附近设备",
            subtitle: "\(appState.discoveredDevices.count)",
            systemImage: "desktopcomputer"
        ) {
            if appState.discoveredDevices.isEmpty {
                LANEmptyState(
                    title: appState.isLANSharingEnabled ? "暂无附近设备" : "共享未开启",
                    systemImage: appState.isLANSharingEnabled ? "wifi.slash" : "power"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.discoveredDevices) { device in
                        SharedDeviceRow(
                            device: device,
                            onTrust: { appState.trustDevice(device) },
                            onRemoveTrust: { appState.removeTrustedDevice(device) }
                        )
                    }
                }
            }
        }
    }

    private var lanSharingBinding: Binding<Bool> {
        Binding(
            get: { appState.isLANSharingEnabled },
            set: { appState.setLANSharingEnabled($0) }
        )
    }

    private var autoCopyReceivedBinding: Binding<Bool> {
        Binding(
            get: { appState.shouldAutoCopyReceivedLANContent },
            set: { appState.setAutoCopyReceivedLANContent($0) }
        )
    }

    private func saveDeviceName() {
        guard canSaveDeviceName else { return }
        appState.setLocalDeviceName(deviceNameDraft)
        deviceNameDraft = appState.localDeviceName
    }
}

private struct LANPreferenceToggle: View {
    let title: String
    let systemImage: String
    let isOn: Binding<Bool>
    var isDisabled = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDisabled ? .tertiary : .secondary)
                .frame(width: 22, height: 22)

            Text(title)
                .font(.callout)
                .foregroundStyle(isDisabled ? .tertiary : .primary)

            Spacer(minLength: 8)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isDisabled)
        }
        .padding(10)
        .background(LANPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(LANPalette.border, lineWidth: 1)
        }
    }
}

private struct LANMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tone: LANTone

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tone.color)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(LANPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(LANPalette.border, lineWidth: 1)
        }
    }
}

private struct LANStatusChip: View {
    let title: String
    let systemImage: String
    let tone: LANTone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tone.color.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(tone.color.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct LANSection<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LANPalette.accent)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LANPalette.panelBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(LANPalette.border, lineWidth: 1)
                    }
            }

            content
        }
    }
}

private struct LANEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(LANPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(LANPalette.border, lineWidth: 1)
        }
    }
}

private struct IncomingClipboardRequestRow: View {
    let request: IncomingClipboardRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LANIconBadge(systemImage: request.payload.type.systemImageName, tone: .orange)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(request.sourceDevice.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(request.payload.type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(LANPalette.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(LANPalette.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }

                Text(previewText)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(request.receivedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button(role: .destructive, action: onReject) {
                    Label("拒绝", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onAccept) {
                    Label("接收", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(LANPalette.highlightBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(LANPalette.orange.opacity(0.28), lineWidth: 1)
        }
    }

    private var previewText: String {
        let trimmedPreview = request.payload.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreview.isEmpty {
            return trimmedPreview
        }

        switch request.payload.type {
        case .image:
            return "图片内容"
        case .text, .url:
            return request.payload.content
        case .file, .html, .richText:
            return request.payload.type.displayName
        }
    }
}

private struct PairingRequestRow: View {
    let request: PairingRequest
    let onTrust: () -> Void

    var body: some View {
        LANDeviceLikeRow(
            title: request.device.name,
            subtitle: "请求配对 · \(request.receivedAt.formatted(date: .omitted, time: .shortened))",
            systemImage: "person.crop.circle.badge.questionmark",
            tone: .accent
        ) {
            Button(action: onTrust) {
                Label("信任", systemImage: "checkmark.shield")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

private struct SharedDeviceRow: View {
    let device: SharedDevice
    let onTrust: () -> Void
    let onRemoveTrust: () -> Void

    var body: some View {
        LANDeviceLikeRow(
            title: device.name,
            subtitle: device.isTrusted ? "已信任 · \(lastSeenText)" : "待信任 · \(lastSeenText)",
            systemImage: device.isTrusted ? "checkmark.shield.fill" : "desktopcomputer",
            tone: device.isTrusted ? .green : .secondary
        ) {
            if device.isTrusted {
                Button(role: .destructive, action: onRemoveTrust) {
                    Label("移除", systemImage: "xmark.shield")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: onTrust) {
                    Label("信任", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var lastSeenText: String {
        device.lastSeenAt.formatted(date: .omitted, time: .shortened)
    }
}

private struct LANDeviceLikeRow<Action: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tone: LANTone
    let action: Action

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tone: LANTone,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.action = action()
    }

    var body: some View {
        HStack(spacing: 12) {
            LANIconBadge(systemImage: systemImage, tone: tone)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            action
        }
        .padding(12)
        .background(LANPalette.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(LANPalette.border, lineWidth: 1)
        }
    }
}

private struct LANIconBadge: View {
    let systemImage: String
    let tone: LANTone

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tone.color.opacity(0.12))

            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone.color)
        }
        .frame(width: 38, height: 38)
    }
}

private enum LANTone {
    case accent
    case green
    case orange
    case secondary

    var color: Color {
        switch self {
        case .accent:
            return LANPalette.accent
        case .green:
            return LANPalette.green
        case .orange:
            return LANPalette.orange
        case .secondary:
            return .secondary
        }
    }
}

private enum LANPalette {
    static let accent = Color.accentColor
    static let green = Color(nsColor: .systemGreen)
    static let orange = Color(nsColor: .systemOrange)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let inputBackground = Color(nsColor: .textBackgroundColor)
    static let highlightBackground = Color(nsColor: .systemOrange).opacity(0.06)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
}
