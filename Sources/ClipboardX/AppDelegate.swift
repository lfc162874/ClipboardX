import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = FileClipboardStore()
    private lazy var monitor = ClipboardMonitor(store: store)
    private lazy var menuBarController = MenuBarController(store: store, monitor: monitor)

    func applicationDidFinishLaunching(_ note: Notification) {
        store.load()
        menuBarController.setup()
        monitor.start()
    }

    func applicationWillTerminate(_ note: Notification) {
        monitor.stop()
        store.save()
    }
}
