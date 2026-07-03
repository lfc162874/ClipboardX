import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published private(set) var items: [ClipboardItem] = []

    private let store = ClipboardStore()
    private let monitor = ClipboardMonitor()
    private let filter = SensitiveFilter()

    init() {
        monitor.onNewText = { [weak self] text in
            Task { @MainActor in
                self?.handleNewText(text)
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
        ClipboardWriter.writeText(item.content)
        store.touch(item)
        items = store.all()
    }

    func search(_ keyword: String) -> [ClipboardItem] {
        store.search(keyword)
    }

    private func handleNewText(_ text: String) {
        guard !filter.shouldIgnore(text) else { return }
        store.upsertText(text)
        items = store.all()
    }
}
