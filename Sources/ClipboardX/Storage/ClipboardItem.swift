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
        hash: String? = nil,
        sourceApp: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.preview = ClipboardItem.makePreview(content, type: type)
        self.hash = hash ?? HashService.sha256(content)
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func makePreview(_ content: String, type: ClipboardItemType) -> String {
        let normalized: String

        if type == .image {
            normalized = URL(fileURLWithPath: content).lastPathComponent
        } else if type == .file {
            normalized = content
                .split(whereSeparator: \.isNewline)
                .map { URL(fileURLWithPath: String($0)).lastPathComponent }
                .joined(separator: ", ")
        } else {
            normalized = content
                .replacingOccurrences(of: "\n", with: " ")
        }

        let trimmed = normalized
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= 120 {
            return trimmed
        }

        return String(trimmed.prefix(120)) + "..."
    }
}
