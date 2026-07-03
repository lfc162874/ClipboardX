import Foundation

enum ClipboardTransferError: LocalizedError {
    case unsupportedType
    case missingImageData

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "第一版局域网共享仅支持文本、链接和图片"
        case .missingImageData:
            return "图片数据不存在，无法发送"
        }
    }
}

struct ClipboardTransferPayload: Codable {
    let id: UUID
    let type: ClipboardItemType
    let content: String
    let preview: String
    let hash: String
    let imageData: Data?
    let createdAt: Date
    let updatedAt: Date

    init(item: ClipboardItem) throws {
        self.id = item.id
        self.type = item.type
        self.preview = item.preview
        self.hash = item.hash
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt

        switch item.type {
        case .text, .url:
            self.content = item.content
            self.imageData = nil
        case .image:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: item.content)) else {
                throw ClipboardTransferError.missingImageData
            }

            self.content = item.hash
            self.imageData = data
        case .file, .html, .richText:
            throw ClipboardTransferError.unsupportedType
        }
    }

    func clipboardContent(from sourceDeviceName: String) -> ClipboardContent {
        switch type {
        case .image:
            return ClipboardContent(
                type: .image,
                content: hash,
                sourceApp: "来自 \(sourceDeviceName)",
                data: imageData
            )
        case .text, .url:
            return ClipboardContent(
                type: type,
                content: content,
                sourceApp: "来自 \(sourceDeviceName)"
            )
        case .file, .html, .richText:
            return ClipboardContent(
                type: .text,
                content: content,
                sourceApp: "来自 \(sourceDeviceName)"
            )
        }
    }
}

enum LANMessageKind: String, Codable {
    case pairingRequest
    case clipboardItem
}

struct LANMessage: Codable {
    let kind: LANMessageKind
    let sourceDevice: SharedDeviceIdentity
    let payload: ClipboardTransferPayload?
}
