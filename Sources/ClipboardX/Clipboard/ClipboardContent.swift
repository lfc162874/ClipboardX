import Foundation

struct ClipboardContent: Equatable {
    let type: ClipboardItemType
    let content: String
    let sourceApp: String?
    let data: Data?

    init(type: ClipboardItemType, content: String, sourceApp: String? = nil, data: Data? = nil) {
        self.type = type
        self.content = content
        self.sourceApp = sourceApp
        self.data = data
    }
}
