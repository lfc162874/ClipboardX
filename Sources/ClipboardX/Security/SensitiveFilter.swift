import Foundation

struct SensitiveFilter {
    private let blockedPatterns = [
        "password=",
        "Authorization:",
        "Bearer ",
        "sk-",
        "AKIA",
        "-----BEGIN PRIVATE KEY-----",
        "验证码",
        "verification code"
    ]

    func shouldIgnore(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        return blockedPatterns.contains { pattern in
            normalized.localizedCaseInsensitiveContains(pattern)
        }
    }
}
