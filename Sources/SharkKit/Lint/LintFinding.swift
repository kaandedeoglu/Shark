import Foundation

public struct LintFinding: Equatable, Codable {
    public enum Rule: String, Codable {
        case missingKey = "missing-key"
        case orphanedKey = "orphaned-key"
        case placeholderMismatch = "placeholder-mismatch"

        /// Orphaned keys are clutter, not breakage — they only fail the run in --strict mode
        public var failsByDefault: Bool {
            switch self {
                case .missingKey, .placeholderMismatch: return true
                case .orphanedKey: return false
            }
        }
    }

    public let rule: Rule
    public let table: String
    public let key: String
    public let locale: String
    public let message: String
    public let path: String?

    public init(rule: Rule, table: String, key: String, locale: String, message: String, path: String?) {
        self.rule = rule
        self.table = table
        self.key = key
        self.locale = locale
        self.message = message
        self.path = path
    }
}
