import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ClipboardStore {
    private enum MetadataKey {
        static let legacyJSONMigrated = "legacy_json_migrated"
    }

    private var items: [ClipboardItem] = []
    private let maxItems = 1000
    private let databaseURL: URL
    private let legacyJSONURL: URL
    private let imagesDirectoryURL: URL
    private let decoder = JSONDecoder()
    private var database: OpaquePointer?

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ClipboardX", isDirectory: true)

        let directory = supportDirectory ?? fileManager.temporaryDirectory
            .appendingPathComponent("ClipboardX", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.databaseURL = directory.appendingPathComponent("clipboard-history.sqlite")
        self.legacyJSONURL = directory.appendingPathComponent("clipboard-history.json")
        self.imagesDirectoryURL = directory.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)

        decoder.dateDecodingStrategy = .iso8601

        openDatabase()
        createSchema()
        load()
        migrateLegacyJSONIfNeeded()
    }

    deinit {
        sqlite3_close(database)
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
            let updatedItem = ClipboardItem(
                id: existing.id,
                type: payload.type,
                content: payload.content,
                hash: payload.hash,
                sourceApp: content.sourceApp ?? existing.sourceApp,
                isPinned: existing.isPinned,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
            items[index] = updatedItem
            persist(updatedItem)
            return
        }

        let item = ClipboardItem(
            type: payload.type,
            content: payload.content,
            hash: payload.hash,
            sourceApp: content.sourceApp
        )
        items.insert(item, at: 0)
        persist(item)
        trim()
    }

    func upsertText(_ text: String) {
        guard let content = ClipboardContentClassifier.classifyText(text) else { return }
        upsert(content)
    }

    func touch(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].updatedAt = Date()
        persist(items[index])
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items[index].updatedAt = Date()
        persist(items[index])
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        deleteFromDatabase(item)
        removeStoredImagesIfUnused([item])
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
        execute("DELETE FROM clipboard_items")
    }

    private func openDatabase() {
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            print("ClipboardX failed to open SQLite database")
            database = nil
            return
        }

        execute("PRAGMA journal_mode=WAL")
        execute("PRAGMA foreign_keys=ON")
    }

    private func createSchema() {
        execute(
            """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY NOT NULL,
                type TEXT NOT NULL,
                content TEXT NOT NULL,
                preview TEXT NOT NULL,
                hash TEXT NOT NULL UNIQUE,
                source_app TEXT,
                is_pinned INTEGER NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )

        execute(
            """
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_updated_at
            ON clipboard_items(updated_at DESC);
            """
        )

        execute(
            """
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_type
            ON clipboard_items(type);
            """
        )

        execute(
            """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            """
        )
    }

    private func load() {
        guard let database else {
            items = []
            return
        }

        let sql = """
        SELECT id, type, content, hash, source_app, is_pinned, created_at, updated_at
        FROM clipboard_items
        ORDER BY is_pinned DESC, updated_at DESC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError("ClipboardX failed to load history")
            items = []
            return
        }
        defer { sqlite3_finalize(statement) }

        var loadedItems: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = columnText(statement, 0),
                  let id = UUID(uuidString: idText),
                  let typeText = columnText(statement, 1),
                  let type = ClipboardItemType(rawValue: typeText),
                  let content = columnText(statement, 2),
                  let hash = columnText(statement, 3) else {
                continue
            }

            let sourceApp = columnText(statement, 4)
            let isPinned = sqlite3_column_int(statement, 5) == 1
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))

            loadedItems.append(
                ClipboardItem(
                    id: id,
                    type: type,
                    content: content,
                    hash: hash,
                    sourceApp: sourceApp,
                    isPinned: isPinned,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }

        items = loadedItems
        trim()
    }

    private func migrateLegacyJSONIfNeeded() {
        guard metadataValue(for: MetadataKey.legacyJSONMigrated) != "true" else { return }
        defer { setMetadataValue("true", for: MetadataKey.legacyJSONMigrated) }

        guard let data = try? Data(contentsOf: legacyJSONURL) else { return }

        do {
            let legacyItems = try decoder.decode([ClipboardItem].self, from: data)
            for item in legacyItems where !items.contains(where: { $0.hash == item.hash }) {
                items.append(item)
                persist(item)
            }
            trim()
        } catch {
            print("ClipboardX failed to migrate legacy JSON history: \(error)")
        }
    }

    private func persist(_ item: ClipboardItem) {
        guard let database else { return }

        let sql = """
        INSERT OR REPLACE INTO clipboard_items (
            id, type, content, preview, hash, source_app, is_pinned, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError("ClipboardX failed to prepare history save")
            return
        }
        defer { sqlite3_finalize(statement) }

        bindText(item.id.uuidString, to: statement, at: 1)
        bindText(item.type.rawValue, to: statement, at: 2)
        bindText(item.content, to: statement, at: 3)
        bindText(item.preview, to: statement, at: 4)
        bindText(item.hash, to: statement, at: 5)

        if let sourceApp = item.sourceApp {
            bindText(sourceApp, to: statement, at: 6)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        sqlite3_bind_int(statement, 7, item.isPinned ? 1 : 0)
        sqlite3_bind_double(statement, 8, item.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 9, item.updatedAt.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            printSQLiteError("ClipboardX failed to save history item")
            return
        }
    }

    private func deleteFromDatabase(_ item: ClipboardItem) {
        guard let database else { return }

        let sql = "DELETE FROM clipboard_items WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError("ClipboardX failed to prepare history delete")
            return
        }
        defer { sqlite3_finalize(statement) }

        bindText(item.id.uuidString, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            printSQLiteError("ClipboardX failed to delete history item")
            return
        }
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard let database else { return false }

        var errorMessage: UnsafeMutablePointer<Int8>?
        let status = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard status == SQLITE_OK else {
            if let errorMessage {
                print("ClipboardX SQLite error: \(String(cString: errorMessage))")
                sqlite3_free(errorMessage)
            }
            return false
        }

        return true
    }

    private func trim() {
        guard items.count > maxItems else { return }
        let sortedItems = all()
        let keptItems = Array(sortedItems.prefix(maxItems))
        let removedItems = Array(sortedItems.dropFirst(maxItems))
        items = keptItems

        for item in removedItems {
            deleteFromDatabase(item)
        }
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

    private func metadataValue(for key: String) -> String? {
        guard let database else { return nil }

        let sql = "SELECT value FROM metadata WHERE key = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError("ClipboardX failed to prepare metadata read")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        bindText(key, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnText(statement, 0)
    }

    private func setMetadataValue(_ value: String, for key: String) {
        guard let database else { return }

        let sql = "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?);"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            printSQLiteError("ClipboardX failed to prepare metadata save")
            return
        }
        defer { sqlite3_finalize(statement) }

        bindText(key, to: statement, at: 1)
        bindText(value, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            printSQLiteError("ClipboardX failed to save metadata")
            return
        }
    }

    private func bindText(_ text: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    private func printSQLiteError(_ message: String) {
        let detail = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown error"
        print("\(message): \(detail)")
    }
}

private struct StoredPayload {
    let type: ClipboardItemType
    let content: String
    let hash: String
}
