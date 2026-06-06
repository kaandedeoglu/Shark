import Testing
import Foundation
@testable import SharkKit

struct LocalizationLinterTests {
    private func makeTable(terms: [String: [String: String]], locales: Set<String>, sourceLocale: String = "en") -> LocalizationTable {
        LocalizationTable(name: "Localizable",
                          sourceLocale: sourceLocale,
                          origin: .stringCatalog(path: "/tmp/Localizable.xcstrings"),
                          locales: locales,
                          terms: terms.mapValues { $0.mapValues { LocalizationTerm(value: $0, state: nil) } },
                          skippedPluralKeys: [])
    }

    @Test func missingKeyIsFound() {
        let table = makeTable(terms: ["GREETING": ["en": "Hello"],
                                      "BYE": ["en": "Bye", "de": "Tschüss"]],
                              locales: ["en", "de"])
        let findings = LocalizationLinter.lint(tables: [table])

        #expect(findings.count == 1)
        #expect(findings[0].rule == .missingKey)
        #expect(findings[0].key == "GREETING")
        #expect(findings[0].locale == "de")
    }

    @Test func emptyTranslationCountsAsMissing() {
        let table = makeTable(terms: ["GREETING": ["en": "Hello", "de": ""]], locales: ["en", "de"])
        let findings = LocalizationLinter.lint(tables: [table])
        #expect(findings.map(\.rule) == [.missingKey])
    }

    // Real-world regression: a key that is empty everywhere (including the
    // source) is one dead key, not N missing translations
    @Test func emptySourceValueIsReportedOnceAtTheRoot() {
        let table = makeTable(terms: ["DEAD_KEY": ["en": "", "de": "", "fr": ""]], locales: ["en", "de", "fr"])
        let findings = LocalizationLinter.lint(tables: [table])

        #expect(findings.count == 1)
        #expect(findings[0].rule == .emptySourceValue)
        #expect(findings[0].locale == "en")
        #expect(findings[0].rule.failsByDefault)
    }

    @Test func orphanedKeyIsFound() {
        let table = makeTable(terms: ["OLD_KEY": ["de": "Veraltet"]], locales: ["en", "de"])
        let findings = LocalizationLinter.lint(tables: [table])

        #expect(findings.count == 1)
        #expect(findings[0].rule == .orphanedKey)
        #expect(findings[0].locale == "de")
        #expect(findings[0].rule.failsByDefault == false)
    }

    @Test func placeholderMismatchIsFound() {
        let table = makeTable(terms: ["COUNT": ["en": "%d items in %@", "de": "%@ Elemente in %@"]],
                              locales: ["en", "de"])
        let findings = LocalizationLinter.lint(tables: [table])

        #expect(findings.count == 1)
        #expect(findings[0].rule == .placeholderMismatch)
        #expect(findings[0].message.contains("%1$d"))
    }

    @Test func positionalReorderingIsNotAMismatch() {
        // German reorders the arguments — same argument list, no finding
        let table = makeTable(terms: ["WELCOME": ["en": "%@ joined %@", "de": "%2$@ wurde von %1$@ betreten"]],
                              locales: ["en", "de"])
        #expect(LocalizationLinter.lint(tables: [table]).isEmpty)
    }

    @Test func missingPlaceholderInTranslationIsAMismatch() {
        #expect(LocalizationLinter.placeholderMismatch(source: "Hello %@, you have %d items", translation: "Hallo, Du hast %d Dinge") != nil)
        #expect(LocalizationLinter.placeholderMismatch(source: "Hello %@", translation: "Hallo %@") == nil)
        #expect(LocalizationLinter.placeholderMismatch(source: "100%% done", translation: "100%% fertig") == nil)
    }

    // Real-world regression: prose percent signs are not placeholders.
    // The space is a printf flag and a/e/i are valid conversions, so a naive
    // parse reads "25% and" as %a and "25% e la" as %e.
    @Test func prosePercentSignsAreNotPlaceholders() {
        #expect(LocalizationLinter.placeholderMismatch(
            source: "the battery level needs to be at least 25% and the low power mode disabled",
            translation: "il livello della batteria deve essere almeno del 25% e la modalità disattivata") == nil)
        #expect(LocalizationLinter.placeholderMismatch(
            source: "the battery level needs to be at least 25% and the low power mode disabled",
            translation: "der Akkustand muss mindestens 25% betragen") == nil)
        // A letter glued to the conversion is prose, not a placeholder
        #expect(LocalizationLinter.placeholderMismatch(
            source: "We are 100% in agreement",
            translation: "Wir sind 100%ig einverstanden") == nil)
        // Real placeholders right next to prose percent signs still count
        #expect(LocalizationLinter.placeholderMismatch(
            source: "%d attempts left at 25% and falling",
            translation: "Noch Versuche übrig") != nil)
        #expect(LocalizationLinter.placeholderMismatch(
            source: "%d attempts left at 25% and falling",
            translation: "Noch %d Versuche übrig bei 25% und sinkend") == nil)
    }

    @Test func cleanTableProducesNoFindings() {
        let table = makeTable(terms: ["GREETING": ["en": "Hello %@", "de": "Hallo %@"]], locales: ["en", "de"])
        #expect(LocalizationLinter.lint(tables: [table]).isEmpty)
    }

    @Test func githubFormatEmitsAnnotations() {
        let finding = LintFinding(rule: .missingKey, table: "Localizable", key: "X", locale: "de",
                                  message: "\"X\" is not translated in de", path: "/tmp/de.lproj/Localizable.strings")
        let report = LintReportFormatter.report(findings: [finding], skippedPluralKeys: [:], format: .github)
        #expect(report == "::error file=/tmp/de.lproj/Localizable.strings,title=shark lint missing-key::\"X\" is not translated in de")
    }

    @Test func jsonFormatRoundTrips() throws {
        let finding = LintFinding(rule: .placeholderMismatch, table: "Localizable", key: "X", locale: "fr",
                                  message: "mismatch", path: nil)
        let report = LintReportFormatter.report(findings: [finding], skippedPluralKeys: ["Localizable": ["PLURAL_KEY"]], format: .json)

        struct Decoded: Codable {
            let findings: [LintFinding]
            let skippedPluralKeys: [String: [String]]
        }
        let decoded = try JSONDecoder().decode(Decoded.self, from: report.data(using: .utf8)!)
        #expect(decoded.findings == [finding])
        #expect(decoded.skippedPluralKeys == ["Localizable": ["PLURAL_KEY"]])
    }

    @Test func textFormatSummarizes() {
        let report = LintReportFormatter.report(findings: [], skippedPluralKeys: [:], format: .text)
        #expect(report.contains("No localization issues found."))
    }
}
