import Foundation

final class ClipboardStore {
    private var items: [ClipboardItem] = []
    private let maxItems = 1000

    func all() -> [ClipboardItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func upsertText(_ text: String) {
        let hash = HashService.sha256(text)

        if let index = items.firstIndex(where: { $0.hash == hash }) {
            items[index].updatedAt = Date()
            return
        }

        let item = ClipboardItem(type: .text, content: text)
        items.insert(item, at: 0)

        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    func touch(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].updatedAt = Date()
    }

    func search(_ keyword: String) -> [ClipboardItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all() }

        return all().filter { item in
            item.content.localizedCaseInsensitiveContains(trimmed)
            || item.preview.localizedCaseInsensitiveContains(trimmed)
            || item.type.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func clear() {
        items.removeAll()
    }
}
