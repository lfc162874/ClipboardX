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
    private var autoPasteMenuItem: NSMenuItem?
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var targetApplication: NSRunningApplication?
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

        let autoPasteItem = NSMenuItem(title: "", action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPasteMenuItem = autoPasteItem
        menu.addItem(autoPasteItem)

        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 ClipboardX", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        updateMonitoringMenuTitle()
        updateAutoPasteMenuTitle()
    }

    private func bindAppState() {
        appState.prepareForAutoPaste = { [weak self] in
            self?.prepareForAutoPaste()
        }

        appState.$isMonitoring
            .sink { [weak self] _ in
                self?.updateMonitoringMenuTitle()
            }
            .store(in: &cancellables)

        appState.$isAutoPasteEnabled
            .sink { [weak self] _ in
                self?.updateAutoPasteMenuTitle()
            }
            .store(in: &cancellables)

        appState.$isAccessibilityTrusted
            .sink { [weak self] _ in
                self?.updateAutoPasteMenuTitle()
            }
            .store(in: &cancellables)
    }

    @objc private func openHistory() {
        rememberTargetApplication()
        appState.refreshAccessibilityStatus()

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

    @objc private func openSettings() {
        appState.refreshAccessibilityStatus()

        if settingsWindow == nil {
            let view = SettingsView(appState: appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "ClipboardX 设置"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: view)
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleMonitoring() {
        appState.toggleMonitoring()
    }

    @objc private func toggleAutoPaste() {
        appState.toggleAutoPaste()
    }

    @objc private func clearHistory() {
        appState.clearHistory()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === historyWindow {
            historyWindow = nil
        }

        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }

    private func updateMonitoringMenuTitle() {
        monitoringMenuItem?.title = appState.isMonitoring ? "暂停监听" : "继续监听"
    }

    private func updateAutoPasteMenuTitle() {
        autoPasteMenuItem?.title = appState.isAutoPasteEnabled ? "关闭自动粘贴" : "开启自动粘贴"
        autoPasteMenuItem?.state = appState.isAutoPasteEnabled ? .on : .off
        autoPasteMenuItem?.toolTip = appState.isAccessibilityTrusted ? nil : "自动粘贴需要辅助功能权限"
    }

    private func rememberTargetApplication() {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != NSRunningApplication.current.processIdentifier else {
            return
        }

        targetApplication = frontmostApplication
    }

    private func prepareForAutoPaste() {
        historyWindow?.orderOut(nil)
        targetApplication?.activate(options: [])
    }
}
