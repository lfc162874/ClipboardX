import Foundation

final class ClipboardStore {
    private var items: [ClipboardItem] = []
    private let maxItems = 1000
    private let fileURL: URL
    private let imagesDirectoryURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ClipboardX", isDirectory: true)

        let directory = supportDirectory ?? fileManager.temporaryDirectory
            .appendingPathComponent("ClipboardX", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("clipboard-history.json")
        self.imagesDirectoryURL = directory.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)

        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        load()
    }

    func all() -> [ClipboardItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func upsert(_ content: ClipboardContent) {
        guard let payload = storedPayload(for: content) else { return }

        if let index = items.firstIndex(where: { $0.hash == payload.hash }) {
            let existing = items[index]
            items[index] = ClipboardItem(
                id: existing.id,
                type: payload.type,
                content: payload.content,
                hash: payload.hash,
                sourceApp: content.sourceApp ?? existing.sourceApp,
                isPinned: existing.isPinned,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
            save()
            return
        }

        let item = ClipboardItem(
            type: payload.type,
            content: payload.content,
            hash: payload.hash,
            sourceApp: content.sourceApp
        )
        items.insert(item, at: 0)
        trim()
        save()
    }

    func upsertText(_ text: String) {
        guard let content = ClipboardContentClassifier.classifyText(text) else { return }
        upsert(content)
    }

    func touch(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].updatedAt = Date()
        save()
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items[index].updatedAt = Date()
        save()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        removeStoredImagesIfUnused([item])
        save()
    }

    func search(_ keyword: String) -> [ClipboardItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all() }

        return all().filter { item in
            item.content.localizedCaseInsensitiveContains(trimmed)
            || item.preview.localizedCaseInsensitiveContains(trimmed)
            || item.type.rawValue.localizedCaseInsensitiveContains(trimmed)
            || item.type.displayName.localizedCaseInsensitiveContains(trimmed)
            || (item.sourceApp?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    func clear() {
        removeStoredImages(items)
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            items = []
            return
        }

        do {
            items = try decoder.decode([ClipboardItem].self, from: data)
            trim()
        } catch {
            items = []
            print("ClipboardX failed to load history: \(error)")
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(all())
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("ClipboardX failed to save history: \(error)")
        }
    }

    private func trim() {
        guard items.count > maxItems else { return }
        let sortedItems = all()
        let keptItems = Array(sortedItems.prefix(maxItems))
        let removedItems = Array(sortedItems.dropFirst(maxItems))
        items = keptItems
        removeStoredImagesIfUnused(removedItems)
    }

    private func storedPayload(for content: ClipboardContent) -> StoredPayload? {
        switch content.type {
        case .image:
            return storedImagePayload(for: content)
        case .text, .url, .file, .html, .richText:
            return StoredPayload(
                type: content.type,
                content: content.content,
                hash: HashService.sha256(content.content)
            )
        }
    }

    private func storedImagePayload(for content: ClipboardContent) -> StoredPayload? {
        guard let imageData = imageData(for: content) else { return nil }

        let hash = HashService.sha256(imageData)
        let fileURL = imagesDirectoryURL.appendingPathComponent("\(hash).png")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try imageData.write(to: fileURL, options: [.atomic])
            } catch {
                print("ClipboardX failed to save image history: \(error)")
                return nil
            }
        }

        return StoredPayload(type: .image, content: fileURL.path, hash: hash)
    }

    private func imageData(for content: ClipboardContent) -> Data? {
        if let data = content.data {
            return data
        }

        return try? Data(contentsOf: URL(fileURLWithPath: content.content))
    }

    private func removeStoredImagesIfUnused(_ candidates: [ClipboardItem]) {
        let activeImagePaths = Set(items.filter { $0.type == .image }.map(\.content))

        for item in candidates where item.type == .image && !activeImagePaths.contains(item.content) {
            try? FileManager.default.removeItem(atPath: item.content)
        }
    }

    private func removeStoredImages(_ candidates: [ClipboardItem]) {
        for item in candidates where item.type == .image {
            try? FileManager.default.removeItem(atPath: item.content)
        }
    }
}

private struct StoredPayload {
    let type: ClipboardItemType
    let content: String
    let hash: String
}
