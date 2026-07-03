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

    private func handleNewContent(_ content: ClipboardContent) {
        guard !filter.shouldIgnore(content.content) else { return }
        store.upsert(content)
        refreshItems()
    }
}
