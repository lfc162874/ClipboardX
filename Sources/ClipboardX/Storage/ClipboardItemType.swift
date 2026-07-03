enum ClipboardItemType: String, Codable, CaseIterable, Identifiable {
    case text
    case url
    case image
    case file
    case html
    case richText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:
            return "文本"
        case .url:
            return "链接"
        case .image:
            return "图片"
        case .file:
            return "文件"
        case .html:
            return "HTML"
        case .richText:
            return "富文本"
        }
    }

    var systemImageName: String {
        switch self {
        case .text:
            return "doc.text"
        case .url:
            return "link"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .html:
            return "chevron.left.forwardslash.chevron.right"
        case .richText:
            return "textformat"
        }
    }
}
