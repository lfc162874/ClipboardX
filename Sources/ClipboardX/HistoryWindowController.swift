import AppKit
import SwiftUI

final class HistoryWindowController: NSWindowController {
    private let store: ClipboardStore

    init(store: ClipboardStore) {
        self.store = store

        let rootView = HistoryView(store: store)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClipboardX"
        window.setContentSize(NSSize(width: 560, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
