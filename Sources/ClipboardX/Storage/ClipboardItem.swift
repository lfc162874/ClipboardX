import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    let content: String
    let preview: String
    let hash: String
    let sourceApp: String?
    var isPinned: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        content: String,
        sourceApp: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.preview = ClipboardItem.makePreview(content)
        self.hash = HashService.sha256(content)
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func makePreview(_ content: String) -> String {
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.count <= 120 {
            return normalized
        }

        return String(normalized.prefix(120)) + "..."
    }
}
