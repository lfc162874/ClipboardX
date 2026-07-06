import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private enum DefaultsKey {
        static let autoPasteEnabled = "autoPasteEnabled"
        static let customSensitivePatterns = "customSensitivePatterns"
        static let ignoredSourceApps = "ignoredSourceApps"
        static let localDeviceID = "localDeviceID"
        static let localDeviceName = "localDeviceName"
        static let lanSharingEnabled = "lanSharingEnabled"
        static let lanTrustedDeviceIDs = "lanTrustedDeviceIDs"
        static let lanAutoCopyReceivedContent = "lanAutoCopyReceivedContent"
        static let historyShortcut = "historyShortcut"
        static let screenshotShortcut = "screenshotShortcut"
    }

    @Published private(set) var isMonitoring = false
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var isAutoPasteEnabled: Bool
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var customSensitivePatterns: [String]
    @Published private(set) var ignoredSourceApps: [String]
    @Published private(set) var isCapturingScreenshot = false
    @Published private(set) var screenshotErrorMessage: String?
    @Published private(set) var isLANSharingEnabled: Bool
    @Published private(set) var localDeviceName: String
    @Published private(set) var discoveredDevices: [SharedDevice] = []
    @Published private(set) var pairingRequests: [PairingRequest] = []
    @Published private(set) var incomingClipboardRequests: [IncomingClipboardRequest] = []
    @Published private(set) var trustedDeviceIDs: [String]
    @Published private(set) var shouldAutoCopyReceivedLANContent: Bool
    @Published private(set) var lanSharingMessage: String?
    @Published private(set) var historyShortcut: AppShortcut
    @Published private(set) var screenshotShortcut: AppShortcut
    @Published private(set) var hotKeyRegistrationMessage: String?

    private let store = ClipboardStore()
    private let monitor = ClipboardMonitor()
    private let pasteController = PasteController()
    private let lanSharingService: LANSharingService
    private let localDeviceID: String
    private let userDefaults: UserDefaults

    var prepareForAutoPaste: (() -> Void)?
    var showScreenshotPin: ((ClipboardItem) -> Void)?
    var showLANReceivePrompt: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedDeviceID = userDefaults.string(forKey: DefaultsKey.localDeviceID) ?? UUID().uuidString
        userDefaults.set(storedDeviceID, forKey: DefaultsKey.localDeviceID)
        self.localDeviceID = storedDeviceID

        let storedDeviceName = userDefaults.string(forKey: DefaultsKey.localDeviceName)
        let defaultDeviceName = Host.current().localizedName ?? "我的 Mac"
        let effectiveDeviceName = storedDeviceName?.isEmpty == false ? storedDeviceName! : defaultDeviceName
        self.localDeviceName = effectiveDeviceName
        self.isAutoPasteEnabled = userDefaults.bool(forKey: DefaultsKey.autoPasteEnabled)
        self.isAccessibilityTrusted = PasteController.isAccessibilityTrusted
        self.customSensitivePatterns = userDefaults.stringArray(forKey: DefaultsKey.customSensitivePatterns) ?? []
        self.ignoredSourceApps = userDefaults.stringArray(forKey: DefaultsKey.ignoredSourceApps) ?? []
        self.isLANSharingEnabled = userDefaults.bool(forKey: DefaultsKey.lanSharingEnabled)
        let storedTrustedDeviceIDs = userDefaults.stringArray(forKey: DefaultsKey.lanTrustedDeviceIDs) ?? []
        self.trustedDeviceIDs = storedTrustedDeviceIDs
        self.shouldAutoCopyReceivedLANContent = userDefaults.bool(forKey: DefaultsKey.lanAutoCopyReceivedContent)
        self.historyShortcut = Self.shortcut(
            forKey: DefaultsKey.historyShortcut,
            defaultValue: .defaultHistory,
            userDefaults: userDefaults
        )
        self.screenshotShortcut = Self.shortcut(
            forKey: DefaultsKey.screenshotShortcut,
            defaultValue: .defaultScreenshot,
            userDefaults: userDefaults
        )
        self.lanSharingService = LANSharingService(
            localDevice: SharedDeviceIdentity(id: storedDeviceID, name: effectiveDeviceName),
            trustedDeviceIDs: Set(storedTrustedDeviceIDs)
        )
        items = store.all()
        monitor.onNewContent = { [weak self] content in
            Task { @MainActor in
                self?.handleNewContent(content)
            }
        }
        configureLANSharingCallbacks()

        if isLANSharingEnabled {
            lanSharingService.start()
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        monitor.start()
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.stop()
        isMonitoring = false
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func clearHistory() {
        store.clear()
        items = []
    }

    func copy(_ item: ClipboardItem) {
        guard ClipboardWriter.write(item) else { return }
        monitor.markCurrentChangeAsHandled()
        store.touch(item)
        refreshItems()
        pasteIfNeeded()
    }

    func togglePinned(_ item: ClipboardItem) {
        store.togglePinned(item)
        refreshItems()
    }

    func delete(_ item: ClipboardItem) {
        store.delete(item)
        refreshItems()
    }

    func search(_ keyword: String) -> [ClipboardItem] {
        store.search(keyword)
    }

    func refreshItems() {
        items = store.all()
    }

    func captureScreenshotAndPin() async {
        guard !isCapturingScreenshot else { return }
        isCapturingScreenshot = true
        screenshotErrorMessage = nil
        defer { isCapturingScreenshot = false }

        do {
            let content = try await ScreenshotService.captureRegionToPasteboard()
            monitor.markCurrentChangeAsHandled()
            guard let item = store.upsert(content) else { return }
            refreshItems()
            showScreenshotPin?(item)
        } catch ScreenshotServiceError.cancelled {
            return
        } catch {
            screenshotErrorMessage = error.localizedDescription
        }
    }

    func toggleAutoPaste() {
        setAutoPasteEnabled(!isAutoPasteEnabled)
    }

    func setAutoPasteEnabled(_ isEnabled: Bool) {
        if isEnabled && !isAccessibilityTrusted {
            requestAccessibilityPermission()
        }

        isAutoPasteEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: DefaultsKey.autoPasteEnabled)
    }

    func requestAccessibilityPermission() {
        isAccessibilityTrusted = PasteController.requestAccessibilityPermission()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = PasteController.isAccessibilityTrusted
    }

    func addSensitivePattern(_ pattern: String) {
        let normalized = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !containsCaseInsensitive(customSensitivePatterns, normalized) else { return }

        customSensitivePatterns.append(normalized)
        saveCustomSensitivePatterns()
    }

    func removeSensitivePattern(_ pattern: String) {
        customSensitivePatterns.removeAll { $0 == pattern }
        saveCustomSensitivePatterns()
    }

    func resetSensitivePatterns() {
        customSensitivePatterns = []
        saveCustomSensitivePatterns()
    }

    func addIgnoredSourceApp(_ sourceApp: String) {
        let normalized = sourceApp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !containsCaseInsensitive(ignoredSourceApps, normalized) else { return }

        ignoredSourceApps.append(normalized)
        saveIgnoredSourceApps()
    }

    func removeIgnoredSourceApp(_ sourceApp: String) {
        ignoredSourceApps.removeAll { $0 == sourceApp }
        saveIgnoredSourceApps()
    }

    func setLANSharingEnabled(_ isEnabled: Bool) {
        isLANSharingEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: DefaultsKey.lanSharingEnabled)

        if isEnabled {
            updateLANSharingService()
            lanSharingService.start()
        } else {
            lanSharingService.stop()
            discoveredDevices = []
        }
    }

    func setLocalDeviceName(_ name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        localDeviceName = normalized
        userDefaults.set(normalized, forKey: DefaultsKey.localDeviceName)
        updateLANSharingService()
    }

    func setAutoCopyReceivedLANContent(_ isEnabled: Bool) {
        shouldAutoCopyReceivedLANContent = isEnabled
        userDefaults.set(isEnabled, forKey: DefaultsKey.lanAutoCopyReceivedContent)
    }

    func setHistoryShortcut(_ shortcut: AppShortcut) {
        guard shortcut != screenshotShortcut else {
            hotKeyRegistrationMessage = "打开历史记录和截图并固定不能使用同一个快捷键。"
            return
        }

        historyShortcut = shortcut
        saveShortcut(shortcut, forKey: DefaultsKey.historyShortcut)
        hotKeyRegistrationMessage = nil
    }

    func setScreenshotShortcut(_ shortcut: AppShortcut) {
        guard shortcut != historyShortcut else {
            hotKeyRegistrationMessage = "打开历史记录和截图并固定不能使用同一个快捷键。"
            return
        }

        screenshotShortcut = shortcut
        saveShortcut(shortcut, forKey: DefaultsKey.screenshotShortcut)
        hotKeyRegistrationMessage = nil
    }

    func resetHistoryShortcut() {
        setHistoryShortcut(.defaultHistory)
    }

    func resetScreenshotShortcut() {
        setScreenshotShortcut(.defaultScreenshot)
    }

    func setHotKeyRegistrationMessage(_ message: String?) {
        hotKeyRegistrationMessage = message
    }

    func trustDevice(_ device: SharedDevice) {
        guard !trustedDeviceIDs.contains(device.id) else { return }
        trustedDeviceIDs.append(device.id)
        saveTrustedDeviceIDs()
        removePairingRequest(for: device.id)
        updateLANSharingService()

        if discoveredDevices.contains(where: { $0.id == device.id }) {
            lanSharingService.sendPairingRequest(to: device.id)
        }
    }

    func removeTrustedDevice(_ device: SharedDevice) {
        trustedDeviceIDs.removeAll { $0 == device.id }
        saveTrustedDeviceIDs()
        updateLANSharingService()
    }

    func send(_ item: ClipboardItem, to device: SharedDevice) {
        guard trustedDeviceIDs.contains(device.id) else {
            lanSharingMessage = "请先信任目标设备"
            return
        }

        guard !shouldBlockLANSend(item) else {
            lanSharingMessage = "内容命中敏感规则，已阻止发送"
            return
        }

        do {
            let payload = try ClipboardTransferPayload(item: item)
            lanSharingService.send(payload: payload, to: device.id)
            lanSharingMessage = "已发送接收请求到 \(device.name)，等待对方确认"
        } catch {
            lanSharingMessage = error.localizedDescription
        }
    }

    func acceptIncomingClipboardRequest(_ request: IncomingClipboardRequest) {
        guard incomingClipboardRequests.contains(where: { $0.id == request.id }) else { return }
        incomingClipboardRequests.removeAll { $0.id == request.id }

        let content = request.payload.clipboardContent(from: request.sourceDevice.name)
        guard let item = store.upsert(content) else { return }
        refreshItems()
        lanSharingMessage = "已接收来自 \(request.sourceDevice.name) 的内容"

        guard shouldAutoCopyReceivedLANContent else { return }
        ClipboardWriter.write(item)
        monitor.markCurrentChangeAsHandled()
    }

    func rejectIncomingClipboardRequest(_ request: IncomingClipboardRequest) {
        incomingClipboardRequests.removeAll { $0.id == request.id }
        lanSharingMessage = "已拒绝来自 \(request.sourceDevice.name) 的内容"
    }

    private func handleNewContent(_ content: ClipboardContent) {
        guard !shouldIgnoreSourceApp(content.sourceApp) else { return }
        let filter = SensitiveFilter(extraPatterns: customSensitivePatterns)
        guard !filter.shouldIgnore(content.content) else { return }
        store.upsert(content)
        refreshItems()
    }

    private func pasteIfNeeded() {
        guard isAutoPasteEnabled else { return }

        refreshAccessibilityStatus()
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            return
        }

        prepareForAutoPaste?()
        _ = pasteController.pasteAfterDelay()
    }

    private func saveCustomSensitivePatterns() {
        customSensitivePatterns.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        userDefaults.set(customSensitivePatterns, forKey: DefaultsKey.customSensitivePatterns)
    }

    private func saveIgnoredSourceApps() {
        ignoredSourceApps.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        userDefaults.set(ignoredSourceApps, forKey: DefaultsKey.ignoredSourceApps)
    }

    private func saveTrustedDeviceIDs() {
        trustedDeviceIDs.sort()
        userDefaults.set(trustedDeviceIDs, forKey: DefaultsKey.lanTrustedDeviceIDs)
    }

    private func saveShortcut(_ shortcut: AppShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        userDefaults.set(data, forKey: key)
    }

    private static func shortcut(
        forKey key: String,
        defaultValue: AppShortcut,
        userDefaults: UserDefaults
    ) -> AppShortcut {
        guard let data = userDefaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(AppShortcut.self, from: data) else {
            return defaultValue
        }

        return shortcut
    }

    private func configureLANSharingCallbacks() {
        lanSharingService.onDevicesChanged = { [weak self] devices in
            Task { @MainActor in
                self?.discoveredDevices = devices
            }
        }

        lanSharingService.onPairingRequest = { [weak self] device in
            Task { @MainActor in
                self?.handlePairingRequest(from: device)
            }
        }

        lanSharingService.onReceivedPayload = { [weak self] payload, sourceDevice in
            Task { @MainActor in
                self?.handleReceivedLANPayload(payload, from: sourceDevice)
            }
        }

        lanSharingService.onError = { [weak self] message in
            Task { @MainActor in
                self?.lanSharingMessage = message
            }
        }
    }

    private func updateLANSharingService() {
        lanSharingService.update(
            localDevice: SharedDeviceIdentity(id: localDeviceID, name: localDeviceName),
            trustedDeviceIDs: Set(trustedDeviceIDs)
        )
    }

    private func handlePairingRequest(from device: SharedDevice) {
        guard !trustedDeviceIDs.contains(device.id) else { return }
        guard !pairingRequests.contains(where: { $0.id == device.id }) else { return }
        pairingRequests.append(PairingRequest(device: device, receivedAt: Date()))
        lanSharingMessage = "\(device.name) 请求配对"
    }

    private func handleReceivedLANPayload(
        _ payload: ClipboardTransferPayload,
        from sourceDevice: SharedDeviceIdentity
    ) {
        incomingClipboardRequests.append(
            IncomingClipboardRequest(
                sourceDevice: sourceDevice,
                payload: payload,
                receivedAt: Date()
            )
        )
        lanSharingMessage = "\(sourceDevice.name) 发送了剪贴板内容，等待确认接收"
        showLANReceivePrompt?()
    }

    private func removePairingRequest(for deviceID: String) {
        pairingRequests.removeAll { $0.id == deviceID }
    }

    private func shouldBlockLANSend(_ item: ClipboardItem) -> Bool {
        guard item.type == .text || item.type == .url else { return false }
        let filter = SensitiveFilter(extraPatterns: customSensitivePatterns)
        return filter.shouldIgnore(item.content)
    }

    private func shouldIgnoreSourceApp(_ sourceApp: String?) -> Bool {
        guard let sourceApp else { return false }

        return ignoredSourceApps.contains { ignoredApp in
            sourceApp.caseInsensitiveCompare(ignoredApp) == .orderedSame
        }
    }

    private func containsCaseInsensitive(_ values: [String], _ candidate: String) -> Bool {
        values.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
    }
}
