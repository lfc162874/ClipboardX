import Foundation

protocol ClipboardStore: AnyObject {
    var items: [ClipboardItem] { get }

    func load()
    func save()
    func addText(_ text: String)
    func search(_ query: String) -> [ClipboardItem]
    func clear()
}
