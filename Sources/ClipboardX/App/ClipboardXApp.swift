import AppKit
import Carbon
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
    private var historyMenuItem: NSMenuItem?
    private var monitoringMenuItem: NSMenuItem?
    private var autoPasteMenuItem: NSMenuItem?
    private var screenshotMenuItem: NSMenuItem?
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var lanSharingWindow: NSWindow?
    private var targetApplication: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()
    private var reportedHotKeyFailures = Set<String>()
    private let screenshotPinController = ScreenshotPinController()
    private lazy var historyHotKeyController = HotKeyController(
        description: appState.historyShortcut.displayString,
        onRegistrationFailure: { [weak self] message in
            Task { @MainActor in
                self?.appState.setHotKeyRegistrationMessage(message)
                self?.showHotKeyRegistrationFailure(message)
            }
        }
    ) { [weak self] in
        Task { @MainActor in
            self?.openHistory()
        }
    }
    private lazy var screenshotHotKeyController = HotKeyController(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: UInt32(optionKey | shiftKey),
        id: 2,
        description: appState.screenshotShortcut.displayString,
        onRegistrationFailure: { [weak self] message in
            Task { @MainActor in
                self?.appState.setHotKeyRegistrationMessage(message)
                self?.showHotKeyRegistrationFailure(message)
            }
        }
    ) { [weak self] in
        Task { @MainActor in
            self?.captureScreenshotAndPin()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        bindAppState()
        registerHotKeys()
        appState.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        historyHotKeyController.unregister()
        screenshotHotKeyController.unregister()
        appState.stopMonitoring()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardX")

        let menu = NSMenu()
        let historyItem = NSMenuItem(
            title: "打开历史记录",
            action: #selector(openHistory),
            keyEquivalent: appState.historyShortcut.menuKeyEquivalent
        )
        historyMenuItem = historyItem
        configure(historyItem, shortcut: appState.historyShortcut)
        menu.addItem(historyItem)

        let screenshotItem = NSMenuItem(
            title: "截图并固定",
            action: #selector(captureScreenshotAndPin),
            keyEquivalent: appState.screenshotShortcut.menuKeyEquivalent
        )
        configure(screenshotItem, shortcut: appState.screenshotShortcut)
        screenshotMenuItem = screenshotItem
        menu.addItem(screenshotItem)

        menu.addItem(NSMenuItem(title: "局域网共享...", action: #selector(openLANSharing), keyEquivalent: ""))
        menu.addItem(.separator())

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

        appState.showScreenshotPin = { [weak self] item in
            self?.screenshotPinController.show(item: item)
        }

        appState.showLANReceivePrompt = { [weak self] in
            self?.openLANSharing()
            NSApp.requestUserAttention(.informationalRequest)
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

        appState.$isCapturingScreenshot
            .sink { [weak self] isCapturing in
                self?.screenshotMenuItem?.isEnabled = !isCapturing
                self?.screenshotMenuItem?.title = isCapturing ? "正在截图..." : "截图并固定"
            }
            .store(in: &cancellables)

        appState.$historyShortcut
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateShortcutMenuItems()
                self?.registerHotKeys()
            }
            .store(in: &cancellables)

        appState.$screenshotShortcut
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateShortcutMenuItems()
                self?.registerHotKeys()
            }
            .store(in: &cancellables)

        appState.$screenshotErrorMessage
            .compactMap { $0 }
            .sink { message in
                let alert = NSAlert()
                alert.messageText = "截图失败"
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.runModal()
            }
            .store(in: &cancellables)
    }

    @objc private func openHistory() {
        rememberTargetApplication()
        appState.refreshAccessibilityStatus()

        if historyWindow == nil {
            let view = HistoryView(appState: appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
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
                contentRect: NSRect(x: 0, y: 0, width: 740, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
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

    @objc private func openLANSharing() {
        if lanSharingWindow == nil {
            let view = LANSharingView(appState: appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "局域网共享"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: view)
            lanSharingWindow = window
        }

        lanSharingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func captureScreenshotAndPin() {
        Task {
            await appState.captureScreenshotAndPin()
        }
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

        if notification.object as? NSWindow === lanSharingWindow {
            lanSharingWindow = nil
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

    private func showHotKeyRegistrationFailure(_ message: String) {
        guard !reportedHotKeyFailures.contains(message) else { return }
        reportedHotKeyFailures.insert(message)

        let alert = NSAlert()
        alert.messageText = "快捷键注册失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func registerHotKeys() {
        reportedHotKeyFailures.removeAll()
        appState.setHotKeyRegistrationMessage(nil)
        historyHotKeyController.update(
            shortcut: appState.historyShortcut,
            description: "打开历史记录 \(appState.historyShortcut.displayString)"
        )
        screenshotHotKeyController.update(
            shortcut: appState.screenshotShortcut,
            description: "截图并固定 \(appState.screenshotShortcut.displayString)"
        )
    }

    private func updateShortcutMenuItems() {
        configure(historyMenuItem, shortcut: appState.historyShortcut)
        configure(screenshotMenuItem, shortcut: appState.screenshotShortcut)
    }

    private func configure(_ menuItem: NSMenuItem?, shortcut: AppShortcut) {
        menuItem?.keyEquivalent = shortcut.menuKeyEquivalent
        menuItem?.keyEquivalentModifierMask = shortcut.menuModifierMask
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
