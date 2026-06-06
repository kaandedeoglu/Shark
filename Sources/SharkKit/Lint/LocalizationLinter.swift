import Foundation

public enum LocalizationLinter {
    public static func lint(tables: [LocalizationTable]) -> [LintFinding] {
        var findings: [LintFinding] = []
        for table in tables {
            findings += lint(table: table)
        }
        return findings
    }

    private static func lint(table: LocalizationTable) -> [LintFinding] {
        var findings: [LintFinding] = []
        let targetLocales = table.locales.subtracting([table.sourceLocale]).sorted()

        for key in table.terms.keys.sorted() {
            let termsByLocale = table.terms[key] ?? [:]
            guard let sourceTerm = termsByLocale[table.sourceLocale] else {
                for locale in termsByLocale.keys.sorted() {
                    findings.append(LintFinding(rule: .orphanedKey,
                                                table: table.name,
                                                key: key,
                                                locale: locale,
                                                message: "\"\(key)\" exists in \(locale) but not in the source locale \(table.sourceLocale)",
                                                path: table.path(forLocale: locale)))
                }
                continue
            }

            for locale in targetLocales {
                guard let term = termsByLocale[locale], term.value.isEmpty == false else {
                    findings.append(LintFinding(rule: .missingKey,
                                                table: table.name,
                                                key: key,
                                                locale: locale,
                                                message: "\"\(key)\" is not translated in \(locale)",
                                                path: table.path(forLocale: locale)))
                    continue
                }
                if let mismatch = placeholderMismatch(source: sourceTerm.value, translation: term.value) {
                    findings.append(LintFinding(rule: .placeholderMismatch,
                                                table: table.name,
                                                key: key,
                                                locale: locale,
                                                message: "\"\(key)\" in \(locale): \(mismatch)",
                                                path: table.path(forLocale: locale)))
                }
            }
        }
        return findings
    }

    /// Compares the placeholder argument lists of a source string and its
    /// translation. Specifiers are normalized to explicit positions first, so
    /// a translation that reorders via `%2$@ … %1$@` is *not* a mismatch.
    static func placeholderMismatch(source: String, translation: String) -> String? {
        let sourceSet = normalizedPlaceholders(in: source)
        // Without source placeholders no String(format:) call ever happens
        // for this key, so prose percent signs in a translation are harmless
        guard sourceSet.isEmpty == false else { return nil }
        let translationSet = normalizedPlaceholders(in: translation)
        guard sourceSet != translationSet else { return nil }
        let describe = { (set: Set<String>) in set.isEmpty ? "none" : set.sorted().joined(separator: ", ") }
        return "placeholders don't match — source has [\(describe(sourceSet))], translation has [\(describe(translationSet))]"
    }

    /// Conversions worth comparing in UI strings. Scientific/hex-float and
    /// C-string conversions (a, e, g, s, c, p) are excluded — they don't occur
    /// in app localizations but constantly false-positive on prose like
    /// "25% and …" or "25% e la …" (space is a printf flag).
    private static let comparedConversions: Set<Character> = ["@", "d", "D", "i", "u", "U", "f", "x", "X", "o", "O"]

    private static func normalizedPlaceholders(in value: String) -> Set<String> {
        var implicitPosition = 0
        var result: Set<String> = []
        for specifier in FormatSpecifierParser.specifiers(in: value) {
            guard comparedConversions.contains(specifier.conversion) else { continue }
            // "100%ig", "% in" — a letter glued to the conversion is prose
            if specifier.conversion != "@", specifier.followedByLetter { continue }
            let position: Int
            if let explicit = specifier.position {
                position = explicit
            } else {
                implicitPosition += 1
                position = implicitPosition
            }
            result.insert("%\(position)$\(specifier.conversion)")
        }
        return result
    }
}

extension LocalizationTable {
    /// Best file path to attach a finding for the given locale to
    func path(forLocale locale: String) -> String? {
        switch origin {
            case .stringCatalog(let path):
                return path
            case .stringsFiles(let pathsByLocale):
                return pathsByLocale[locale] ?? pathsByLocale[sourceLocale] ?? pathsByLocale.values.sorted().first
        }
    }
}
