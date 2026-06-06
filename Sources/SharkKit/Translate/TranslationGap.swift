import Foundation

/// One missing translation: a key that has a source value but no usable
/// translation in the target locale.
public struct TranslationGap: Equatable, Sendable {
    public let tableName: String
    public let origin: LocalizationTable.Origin
    public let key: String
    public let sourceValue: String
    public let sourceLocale: String
    public let targetLocale: String

    public init(tableName: String, origin: LocalizationTable.Origin, key: String, sourceValue: String, sourceLocale: String, targetLocale: String) {
        self.tableName = tableName
        self.origin = origin
        self.key = key
        self.sourceValue = sourceValue
        self.sourceLocale = sourceLocale
        self.targetLocale = targetLocale
    }
}

public enum TranslationGapAnalyzer {
    /// Only missing or empty entries are gaps. Existing translations —
    /// including ones in needs_review — are never candidates, so the tool is
    /// incapable of overwriting human work.
    public static func gaps(tables: [LocalizationTable], targetLocales: [String]) -> [TranslationGap] {
        var result: [TranslationGap] = []
        for table in tables {
            for key in table.terms.keys.sorted() {
                guard let sourceTerm = table.terms[key]?[table.sourceLocale], sourceTerm.value.isEmpty == false else { continue }
                for locale in targetLocales where locale != table.sourceLocale {
                    let existing = table.terms[key]?[locale]
                    guard existing == nil || existing?.value.isEmpty == true else { continue }
                    result.append(TranslationGap(tableName: table.name,
                                                 origin: table.origin,
                                                 key: key,
                                                 sourceValue: sourceTerm.value,
                                                 sourceLocale: table.sourceLocale,
                                                 targetLocale: locale))
                }
            }
        }
        return result
    }

    /// Gaps whose target is a `.strings` table with no file for the target
    /// locale — Shark can't add files to the Xcode project, so these need a
    /// manually created `<locale>.lproj/<table>.strings` first.
    public static func unsupportedGaps(in gaps: [TranslationGap]) -> [TranslationGap] {
        gaps.filter { gap in
            guard case .stringsFiles(let pathsByLocale) = gap.origin else { return false }
            return pathsByLocale[gap.targetLocale] == nil
        }
    }
}
