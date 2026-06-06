import Testing
import Foundation
@testable import SharkKit

/// Pure unit tests — no MockURLProtocol involvement, safe to run in parallel
struct TranslatorPromptTests {
    @Test func userMessageContainsLocalesAndSortedPayload() throws {
        let message = Translator.userMessage(for: [TestAPI.gap(key: "Z_KEY", source: "Z"),
                                                   TestAPI.gap(key: "A_KEY", source: "A %d")],
                                             rejectionNotes: [:])
        #expect(message.contains("Source locale: en"))
        #expect(message.contains("Target locale: de"))
        let aIndex = try #require(message.range(of: "A_KEY")).lowerBound
        let zIndex = try #require(message.range(of: "Z_KEY")).lowerBound
        #expect(aIndex < zIndex)
    }

    @Test func rejectionNotesAreEmbedded() {
        let message = Translator.userMessage(for: [TestAPI.gap(key: "K", source: "%d")],
                                             rejectionNotes: ["K": "placeholders don't match"])
        #expect(message.contains("A previous attempt was rejected: placeholders don't match"))
    }

    @Test func systemBlocksMarkStablePrefixAsCached() {
        let bare = Translator(client: TestAPI.client()).systemBlocks()
        #expect(bare.count == 1)
        #expect(bare[0].cached)

        let withGlossary = Translator(client: TestAPI.client(), glossary: "Fahrzeug = vehicle").systemBlocks()
        #expect(withGlossary.count == 2)
        #expect(withGlossary[0].cached == false)
        #expect(withGlossary[1].cached)
        #expect(withGlossary[1].text.contains("Fahrzeug"))
    }

    @Test func validationCatchesEmptyAndMismatchedValues() {
        let gap = TestAPI.gap(key: "K", source: "%d items")
        #expect(Translator.validate(value: nil, for: gap) != nil)
        #expect(Translator.validate(value: "", for: gap) != nil)
        #expect(Translator.validate(value: "Keine Specifier", for: gap) != nil)
        #expect(Translator.validate(value: "%d Dinge", for: gap) == nil)
    }
}

struct TranslationGapAnalyzerTests {
    private func makeTable(terms: [String: [String: LocalizationTerm]],
                           locales: Set<String>,
                           origin: LocalizationTable.Origin = .stringCatalog(path: "/tmp/L.xcstrings")) -> LocalizationTable {
        LocalizationTable(name: "Localizable", sourceLocale: "en", origin: origin,
                          locales: locales, terms: terms, skippedPluralKeys: [])
    }

    @Test func missingAndEmptyEntriesAreGaps() {
        let table = makeTable(terms: [
            "MISSING": ["en": .init(value: "Hello", state: nil)],
            "EMPTY": ["en": .init(value: "Bye", state: nil), "de": .init(value: "", state: nil)],
            "DONE": ["en": .init(value: "Done", state: nil), "de": .init(value: "Fertig", state: .translated)],
            "IN_REVIEW": ["en": .init(value: "Review", state: nil), "de": .init(value: "Prüfen", state: .needsReview)],
        ], locales: ["en", "de"])

        let gaps = TranslationGapAnalyzer.gaps(tables: [table], targetLocales: ["de"])
        #expect(Set(gaps.map(\.key)) == ["MISSING", "EMPTY"])
    }

    @Test func newLocaleTranslatesEverything() {
        let table = makeTable(terms: ["A": ["en": .init(value: "A", state: nil)]], locales: ["en"])
        let gaps = TranslationGapAnalyzer.gaps(tables: [table], targetLocales: ["fr", "en"])
        #expect(gaps.count == 1)
        #expect(gaps[0].targetLocale == "fr")
    }

    @Test func stringsTableWithoutLocaleFileIsUnsupported() {
        let table = makeTable(terms: ["A": ["en": .init(value: "A", state: nil)]],
                              locales: ["en"],
                              origin: .stringsFiles(pathsByLocale: ["en": "/tmp/en.lproj/Localizable.strings"]))
        let gaps = TranslationGapAnalyzer.gaps(tables: [table], targetLocales: ["de"])
        #expect(TranslationGapAnalyzer.unsupportedGaps(in: gaps) == gaps)
        #expect(gaps.count == 1)
    }
}

struct TranslationWriteBackTests {
    @Test func routesCatalogTranslationsAndReportsMissingStringsFiles() throws {
        let catalogPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("shark-writeback-\(UUID().uuidString).xcstrings").path
        let catalog = #"""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "BYE" : {
              "localizations" : {
                "en" : { "stringUnit" : { "state" : "translated", "value" : "Goodbye" } }
              }
            }
          },
          "version" : "1.0"
        }
        """#
        try catalog.write(toFile: catalogPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: catalogPath) }

        let catalogGap = TranslationGap(tableName: "Localizable",
                                        origin: .stringCatalog(path: catalogPath),
                                        key: "BYE", sourceValue: "Goodbye",
                                        sourceLocale: "en", targetLocale: "de")
        let orphanGap = TranslationGap(tableName: "Other",
                                       origin: .stringsFiles(pathsByLocale: ["en": "/nonexistent/en.lproj/Other.strings"]),
                                       key: "X", sourceValue: "X",
                                       sourceLocale: "en", targetLocale: "de")

        let summary = try TranslationWriteBack.write([(catalogGap, "Tschüss"), (orphanGap, "X-de")])

        #expect(summary.writtenByLocale == ["de": 1])
        #expect(summary.failed.count == 1)
        #expect(summary.failed.first?.reason.contains("create de.lproj/Other.strings") == true)

        let table = try StringCatalogReader.table(atPath: catalogPath)
        #expect(table.terms["BYE"]?["de"]?.value == "Tschüss")
        #expect(table.terms["BYE"]?["de"]?.state == .needsReview)
    }
}
