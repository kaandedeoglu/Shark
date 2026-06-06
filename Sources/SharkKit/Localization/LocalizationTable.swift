import Foundation

public struct LocalizationTerm: Equatable {
    public enum State: Equatable {
        case translated
        case needsReview
        case other(String)

        init(rawState: String) {
            switch rawState {
                case "translated": self = .translated
                case "needs_review": self = .needsReview
                default: self = .other(rawState)
            }
        }
    }

    public let value: String
    public let state: State?

    public init(value: String, state: State?) {
        self.value = value
        self.state = state
    }
}

/// One logical localization table across all of its locales — either a single
/// `.xcstrings` catalog, or a group of same-named `.strings` files from
/// different `.lproj` folders.
public struct LocalizationTable {
    public enum Origin: Equatable, Sendable {
        case stringCatalog(path: String)
        case stringsFiles(pathsByLocale: [String: String])
    }

    public let name: String
    public let sourceLocale: String
    public let origin: Origin
    public let locales: Set<String>
    /// key → locale → term
    public let terms: [String: [String: LocalizationTerm]]
    /// Keys using plural variations — not handled yet, reported so they don't vanish silently
    public let skippedPluralKeys: Set<String>

    public init(name: String, sourceLocale: String, origin: Origin, locales: Set<String>, terms: [String: [String: LocalizationTerm]], skippedPluralKeys: Set<String>) {
        self.name = name
        self.sourceLocale = sourceLocale
        self.origin = origin
        self.locales = locales
        self.terms = terms
        self.skippedPluralKeys = skippedPluralKeys
    }
}

public enum LocalizationFileError: LocalizedError {
    case invalidStringsFile(path: String)
    case invalidStringCatalog(path: String, underlying: Error?)

    public var errorDescription: String? {
        switch self {
            case .invalidStringsFile(let path):
                return "Invalid .strings file at \(path)"
            case .invalidStringCatalog(let path, let underlying):
                let detail = underlying.map { ": \($0.localizedDescription)" } ?? ""
                return "Invalid .xcstrings catalog at \(path)\(detail)"
        }
    }
}
