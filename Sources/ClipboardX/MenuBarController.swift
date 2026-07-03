import AppKit

final class MenuBarController: NSObject {
    private let store: ClipboardStore
    private let monitor: ClipboardMonitor
    private var statusItem: NSStatusItem?
    private var historyWindowController: HistoryWindowController?

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
        super.init()
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardX")
            button.target = self
            button.action = #selector(openHistory)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Clipboard History", action: #selector(openHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Pause Monitoring", action: #selector(toggleMonitoring), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ClipboardX", action: #selector(quit), keyEquivalent: "q"))

        for menuItem in menu.items {
            menuItem.target = self
        }

        item.menu = menu
    }

    @objc private func openHistory() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController(store: store)
        }
        historyWindowController?.show()
    }

    @objc private func toggleMonitoring(_ sender: NSMenuItem) {
        if monitor.isRunning {
            monitor.stop()
            sender.title = "Resume Monitoring"
        } else {
            monitor.start()
            sender.title = "Pause Monitoring"
        }
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
