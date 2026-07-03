import Foundation

struct SensitiveFilter {
    static let defaultBlockedPatterns = [
        "password=",
        "Authorization:",
        "Bearer ",
        "sk-",
        "AKIA",
        "-----BEGIN PRIVATE KEY-----",
        "验证码",
        "verification code"
    ]

    private let blockedPatterns: [String]

    init(extraPatterns: [String] = []) {
        self.blockedPatterns = Self.defaultBlockedPatterns + extraPatterns
    }

    func shouldIgnore(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        return blockedPatterns.contains { pattern in
            let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPattern.isEmpty else { return false }
            return normalized.localizedCaseInsensitiveContains(trimmedPattern)
        }
    }
}
