import AppKit
import SwiftUI

@main
struct ClipboardXApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var statusItem: NSStatusItem?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        appState.startMonitoring()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardX")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开历史记录", action: #selector(openHistory), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "暂停/继续监听", action: #selector(toggleMonitoring), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 ClipboardX", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    @objc private func openHistory() {
        if historyWindow == nil {
            let view = HistoryView(appState: appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "ClipboardX"
            window.contentView = NSHostingView(rootView: view)
            historyWindow = window
        }

        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMonitoring() {
        appState.toggleMonitoring()
    }

    @objc private func clearHistory() {
        appState.clearHistory()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
