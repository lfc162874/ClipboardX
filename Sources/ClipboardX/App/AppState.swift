import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private enum DefaultsKey {
        static let autoPasteEnabled = "autoPasteEnabled"
        static let customSensitivePatterns = "customSensitivePatterns"
        static let ignoredSourceApps = "ignoredSourceApps"
    }

    @Published private(set) var isMonitoring = false
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var isAutoPasteEnabled: Bool
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var customSensitivePatterns: [String]
    @Published private(set) var ignoredSourceApps: [String]

    private let store = ClipboardStore()
    private let monitor = ClipboardMonitor()
    private let pasteController = PasteController()
    private let userDefaults: UserDefaults

    var prepareForAutoPaste: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isAutoPasteEnabled = userDefaults.bool(forKey: DefaultsKey.autoPasteEnabled)
        self.isAccessibilityTrusted = PasteController.isAccessibilityTrusted
        self.customSensitivePatterns = userDefaults.stringArray(forKey: DefaultsKey.customSensitivePatterns) ?? []
        self.ignoredSourceApps = userDefaults.stringArray(forKey: DefaultsKey.ignoredSourceApps) ?? []
        items = store.all()
        monitor.onNewContent = { [weak self] content in
            Task { @MainActor in
                self?.handleNewContent(content)
            }
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
