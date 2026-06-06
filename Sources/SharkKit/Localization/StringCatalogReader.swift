import Foundation

/// Reads a `.xcstrings` catalog into a `LocalizationTable` covering all
/// locales. Built on `JSONSerialization` rather than the codegen's `Codable`
/// models so unknown fields survive a read-modify-write round trip.
public enum StringCatalogReader {
    public static func table(atPath path: String) throws -> LocalizationTable {
        let root = try StringCatalogReader.jsonObject(atPath: path)

        guard let sourceLanguage = root["sourceLanguage"] as? String,
              let strings = root["strings"] as? [String: Any] else {
            throw LocalizationFileError.invalidStringCatalog(path: path, underlying: nil)
        }

        var terms: [String: [String: LocalizationTerm]] = [:]
        var locales: Set<String> = [sourceLanguage]
        var skippedPluralKeys: Set<String> = []

        for (key, rawEntry) in strings {
            guard let entry = rawEntry as? [String: Any] else { continue }
            guard let localizations = entry["localizations"] as? [String: Any], localizations.isEmpty == false else {
                // No localizations at all — the key itself acts as the source value
                terms[key] = [sourceLanguage: LocalizationTerm(value: key, state: nil)]
                continue
            }

            var termsByLocale: [String: LocalizationTerm] = [:]
            for (locale, rawLocalization) in localizations {
                guard let localization = rawLocalization as? [String: Any] else { continue }
                locales.insert(locale)
                if localization["variations"] != nil {
                    skippedPluralKeys.insert(key)
                    continue
                }
                guard let stringUnit = localization["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String else { continue }
                let state = (stringUnit["state"] as? String).map(LocalizationTerm.State.init(rawState:))
                termsByLocale[locale] = LocalizationTerm(value: value, state: state)
            }
            if skippedPluralKeys.contains(key) == false {
                terms[key] = termsByLocale
            }
        }

        return LocalizationTable(name: path.lastPathComponent.replacingOccurrences(of: ".xcstrings", with: ""),
                                 sourceLocale: sourceLanguage,
                                 origin: .stringCatalog(path: path),
                                 locales: locales,
                                 terms: terms,
                                 skippedPluralKeys: skippedPluralKeys)
    }

    /// Loads the catalog's raw JSON object, repairing raw newlines inside
    /// string literals if necessary (same fallback the codegen path uses).
    static func jsonObject(atPath path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        do {
            return try parse(data, path: path)
        } catch {
            guard let jsonString = String(data: data, encoding: .utf8),
                  let repairedData = LocalizationEnumBuilder.fixMultilineStringsInJSON(jsonString).data(using: .utf8) else {
                throw error
            }
            return try parse(repairedData, path: path)
        }
    }

    private static func parse(_ data: Data, path: String) throws -> [String: Any] {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LocalizationFileError.invalidStringCatalog(path: path, underlying: nil)
            }
            return object
        } catch let error as LocalizationFileError {
            throw error
        } catch {
            throw LocalizationFileError.invalidStringCatalog(path: path, underlying: error)
        }
    }
}
