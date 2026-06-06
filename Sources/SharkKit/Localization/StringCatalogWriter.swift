import Foundation

/// Inserts translations into a `.xcstrings` catalog via read-modify-write on
/// the raw JSON object, so existing entries and unknown fields stay untouched.
public enum StringCatalogWriter {
    public struct Translation {
        public let key: String
        public let locale: String
        public let value: String

        public init(key: String, locale: String, value: String) {
            self.key = key
            self.locale = locale
            self.value = value
        }
    }

    /// Adds the given translations, marking each as `needs_review` so Xcode's
    /// String Catalog editor surfaces them for human review. Existing
    /// localizations are never overwritten.
    public static func add(_ translations: [Translation], toCatalogAtPath path: String) throws {
        guard translations.isEmpty == false else { return }

        var root = try StringCatalogReader.jsonObject(atPath: path)
        guard var strings = root["strings"] as? [String: Any] else {
            throw LocalizationFileError.invalidStringCatalog(path: path, underlying: nil)
        }

        for translation in translations {
            var entry = strings[translation.key] as? [String: Any] ?? [:]
            var localizations = entry["localizations"] as? [String: Any] ?? [:]
            guard localizations[translation.locale] == nil else { continue }
            localizations[translation.locale] = [
                "stringUnit": [
                    "state": "needs_review",
                    "value": translation.value,
                ]
            ]
            entry["localizations"] = localizations
            strings[translation.key] = entry
        }

        root["strings"] = strings
        let output = XcodeStyleJSON.string(from: root) + "\n"
        try output.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
}
