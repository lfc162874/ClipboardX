import AppKit
import Combine
import SwiftUI

@main
@MainActor
struct ClipboardXApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let appState = AppState()
    private var statusItem: NSStatusItem?
    private var monitoringMenuItem: NSMenuItem?
    private var historyWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private lazy var hotKeyController = HotKeyController { [weak self] in
        Task { @MainActor in
            self?.openHistory()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        bindAppState()
        hotKeyController.register()
        appState.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController.unregister()
        appState.stopMonitoring()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardX")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开历史记录", action: #selector(openHistory), keyEquivalent: "v"))

        let monitoringItem = NSMenuItem(title: "", action: #selector(toggleMonitoring), keyEquivalent: "p")
        monitoringMenuItem = monitoringItem
        menu.addItem(monitoringItem)

        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 ClipboardX", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        updateMonitoringMenuTitle()
    }

    private func bindAppState() {
        appState.$isMonitoring
            .sink { [weak self] _ in
                self?.updateMonitoringMenuTitle()
            }
            .store(in: &cancellables)
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
            window.isReleasedWhenClosed = false
            window.delegate = self
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

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === historyWindow else { return }
        historyWindow = nil
    }

    private func updateMonitoringMenuTitle() {
        monitoringMenuItem?.title = appState.isMonitoring ? "暂停监听" : "继续监听"
    }
}
