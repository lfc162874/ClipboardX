import Foundation

enum ClipboardContentClassifier {
    static func classifyText(_ text: String) -> ClipboardContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fileURL = URL(string: trimmed),
           fileURL.isFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            return ClipboardContent(type: .file, content: fileURL.path)
        }

        if isExistingFilePath(trimmed) {
            return ClipboardContent(type: .file, content: expandedPath(trimmed))
        }

        if isWebURL(trimmed) {
            return ClipboardContent(type: .url, content: trimmed)
        }

        return ClipboardContent(type: .text, content: text)
    }

    private static func isWebURL(_ text: String) -> Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }

        return true
    }

    private static func isExistingFilePath(_ text: String) -> Bool {
        FileManager.default.fileExists(atPath: expandedPath(text))
    }

    private static func expandedPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
