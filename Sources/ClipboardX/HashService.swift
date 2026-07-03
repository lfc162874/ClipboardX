import Foundation

enum HashService {
    static func sha256(_ text: String) -> String {
        var hash: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211

        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        return String(format: "%016llx", hash)
    }
}
