import Foundation

enum SensitiveFilter {
    private static let blockedFragments = [
        "password=",
        "authorization:",
        "bearer ",
        "-----begin private key-----",
        "verification code",
        "验证码"
    ]

    static func shouldIgnore(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        if text.count <= 6, text.allSatisfy({ $0.isNumber }) {
            return true
        }

        return blockedFragments.contains { lowercased.contains($0) }
    }
}
