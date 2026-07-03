import AppKit

enum ClipboardWriter {
    @discardableResult
    static func write(_ item: ClipboardItem) -> Bool {
        switch item.type {
        case .file:
            return writeFilePaths(item.content)
        case .image:
            return writeImage(atPath: item.content)
        case .text, .url, .html, .richText:
            return writeText(item.content)
        }
    }

    @discardableResult
    static func writeText(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    private static func writeFilePaths(_ content: String) -> Bool {
        let paths = content
            .split(whereSeparator: \.isNewline)
            .map { NSString(string: String($0)).expandingTildeInPath }
            .filter { FileManager.default.fileExists(atPath: $0) }

        guard !paths.isEmpty else {
            return writeText(content)
        }

        let urls = paths.map { NSURL(fileURLWithPath: $0) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects(urls)
    }

    @discardableResult
    private static func writeImage(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        guard let data = try? Data(contentsOf: url) else {
            return writeText(path)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let pngType = NSPasteboard.PasteboardType("public.png")
        let wrotePNG = pasteboard.setData(data, forType: pngType)

        if let image = NSImage(data: data) {
            return pasteboard.writeObjects([image]) || wrotePNG
        }

        return wrotePNG
    }
}
