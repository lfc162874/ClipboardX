enum ClipboardItemType: String, Codable, CaseIterable, Identifiable {
    case text
    case url
    case image
    case file
    case html
    case richText

    var id: String { rawValue }
}
