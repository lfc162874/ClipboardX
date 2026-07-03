import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: ClipboardKind
    var content: String
    var preview: String
    var contentHash: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: ClipboardKind = .text,
        content: String,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.preview = ClipboardItem.makePreview(from: content)
        self.contentHash = HashService.sha256(kind.rawValue + ":" + content)
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func makePreview(from content: String, limit: Int = 120) -> String {
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.count <= limit {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<endIndex]) + "..."
    }
}
