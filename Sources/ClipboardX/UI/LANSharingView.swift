import SwiftUI

struct LANSharingView: View {
    @ObservedObject var appState: AppState
    @State private var deviceNameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 580, minHeight: 500)
        .onAppear {
            deviceNameDraft = appState.localDeviceName
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("局域网共享")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("发现可信设备，手动发送文本、链接和图片历史。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("开启", isOn: lanSharingBinding)
                .toggleStyle(.switch)
        }
        .padding(18)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                messageSection
                incomingClipboardSection
                deviceNameSection
                receivePolicySection
                pairingSection
                discoveredDevicesSection

                Text("第一版只支持文本、链接和图片的手动发送。收到内容后需要手动确认接收；文件真实传输、自动同步和跨公网同步暂不支持。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var deviceNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本机设备")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("本机设备名", text: $deviceNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveDeviceName)

                Button(action: saveDeviceName) {
                    Label("保存", systemImage: "checkmark")
                }
                .disabled(deviceNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var receivePolicySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("接收策略")
                .font(.headline)

            Toggle("接收后自动复制到系统剪贴板", isOn: autoCopyReceivedBinding)
                .toggleStyle(.switch)
                .disabled(!appState.isLANSharingEnabled)
                .help("关闭时，接收内容只进入历史记录，不覆盖当前剪贴板")
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let message = appState.lanSharingMessage {
            Label(message, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配对请求")
                .font(.headline)

            if appState.pairingRequests.isEmpty {
                LANEmptyRow(title: "暂无配对请求")
            } else {
                ForEach(appState.pairingRequests) { request in
                    HStack(spacing: 8) {
                        Label(request.device.name, systemImage: "person.crop.circle.badge.questionmark")
                            .lineLimit(1)

                        Spacer()

                        Button {
                            appState.trustDevice(request.device)
                        } label: {
                            Label("信任", systemImage: "checkmark.shield")
                        }
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var incomingClipboardSection: some View {
        if !appState.incomingClipboardRequests.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("待接收内容")
                    .font(.headline)

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

    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("发现的设备")
                .font(.headline)

            if appState.discoveredDevices.isEmpty {
                LANEmptyRow(title: appState.isLANSharingEnabled ? "暂未发现其他设备" : "开启局域网共享后开始发现设备")
            } else {
                ForEach(appState.discoveredDevices) { device in
                    HStack(spacing: 8) {
                        Label(device.name, systemImage: device.isTrusted ? "checkmark.shield" : "desktopcomputer")
                            .lineLimit(1)

                        Spacer()

                        if device.isTrusted {
                            Button(role: .destructive) {
                                appState.removeTrustedDevice(device)
                            } label: {
                                Label("移除信任", systemImage: "xmark.shield")
                            }
                        } else {
                            Button {
                                appState.trustDevice(device)
                            } label: {
                                Label("信任并请求配对", systemImage: "checkmark.shield")
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Divider()
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
        appState.setLocalDeviceName(deviceNameDraft)
        deviceNameDraft = appState.localDeviceName
    }
}

private struct LANEmptyRow: View {
    let title: String

    var body: some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

private struct IncomingClipboardRequestRow: View {
    let request: IncomingClipboardRequest
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: request.payload.type.systemImageName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text("来自 \(request.sourceDevice.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(request.payload.type.displayName)
                    Text("·")
                    Text(request.receivedAt, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(previewText)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button(role: .destructive, action: onReject) {
                    Label("拒绝", systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                Button(action: onAccept) {
                    Label("接收", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
