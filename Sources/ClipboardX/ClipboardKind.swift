import Foundation

struct ClipboardKind: RawRepresentable, Codable, Equatable {
    let rawValue: String

    static let text = ClipboardKind(rawValue: "text")
    static let link = ClipboardKind(rawValue: "link")
    static let image = ClipboardKind(rawValue: "image")
}
