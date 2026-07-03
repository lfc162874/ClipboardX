import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    var onNewContent: ((ClipboardContent) -> Void)?
    var isRunning: Bool {
        timer != nil
    }

    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func markCurrentChangeAsHandled() {
        lastChangeCount = pasteboard.changeCount
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        if let fileContent = readFileContent() {
            onNewContent?(fileContent)
            return
        }

        if let imageContent = readImageContent() {
            onNewContent?(imageContent)
            return
        }

        guard let text = pasteboard.string(forType: .string),
              let content = ClipboardContentClassifier.classifyText(text) else {
            return
        }

        onNewContent?(content.withSourceApp(currentSourceAppName))
    }

    private func readFileContent() -> ClipboardContent? {
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []

        let paths = objects.compactMap { object -> String? in
            if let url = object as? URL {
                return url.path
            }

            return (object as? NSURL)?.path
        }

        guard !paths.isEmpty else { return nil }

        return ClipboardContent(type: .file, content: paths.joined(separator: "\n"), sourceApp: currentSourceAppName)
    }

    private func readImageContent() -> ClipboardContent? {
        guard let imageData = readPNGImageData() else { return nil }
        let hash = HashService.sha256(imageData)
        return ClipboardContent(
            type: .image,
            content: hash,
            sourceApp: currentSourceAppName,
            data: imageData
        )
    }

    private func readPNGImageData() -> Data? {
        let pngType = NSPasteboard.PasteboardType("public.png")
        if let pngData = pasteboard.data(forType: pngType) {
            return pngData
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private var currentSourceAppName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}

private extension ClipboardContent {
    func withSourceApp(_ sourceApp: String?) -> ClipboardContent {
        ClipboardContent(type: type, content: content, sourceApp: sourceApp, data: data)
    }
}
