import Foundation

final class FileClipboardStore: ClipboardStore, ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 1000
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipboardX", isDirectory: true)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("clipboard-history.json")
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("ClipboardX failed to save history: \(error)")
        }
    }

    func addText(_ text: String) {
        guard !SensitiveFilter.shouldIgnore(text) else {
            return
        }

        let newItem = ClipboardItem(content: text)

        if let index = items.firstIndex(where: { $0.contentHash == newItem.contentHash }) {
            items[index].updatedAt = Date()
            let existing = items.remove(at: index)
            items.insert(existing, at: 0)
        } else {
            items.insert(newItem, at: 0)
        }

        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    func search(_ query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return sortedItems()
        }

        return sortedItems().filter {
            $0.content.localizedCaseInsensitiveContains(trimmed) ||
            $0.preview.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func sortedItems() -> [ClipboardItem] {
        items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }
}
