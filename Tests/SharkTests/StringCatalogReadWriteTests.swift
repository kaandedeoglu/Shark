import Testing
import Foundation
@testable import SharkKit

struct StringCatalogReadWriteTests {
    private static let fixture = #"""
    {
      "sourceLanguage" : "en",
      "strings" : {
        "EMPTY_KEY" : {

        },
        "GREETING" : {
          "extractionState" : "manual",
          "localizations" : {
            "de" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Hallo"
              }
            },
            "en" : {
              "stringUnit" : {
                "state" : "translated",
                "value" : "Hello %@!"
              }
            }
          }
        },
        "REVIEW_ME" : {
          "localizations" : {
            "en" : {
              "stringUnit" : {
                "state" : "needs_review",
                "value" : "Review me"
              }
            }
          }
        }
      },
      "version" : "1.0"
    }

    """#

    private func writeFixture(_ contents: String = fixture) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("shark-test-\(UUID().uuidString).xcstrings").path
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test func readerCoversAllLocalesAndStates() throws {
        let path = try writeFixture()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let table = try StringCatalogReader.table(atPath: path)

        #expect(table.sourceLocale == "en")
        #expect(table.locales == ["en", "de"])
        #expect(table.terms["GREETING"]?["de"]?.value == "Hallo")
        #expect(table.terms["GREETING"]?["de"]?.state == .translated)
        #expect(table.terms["REVIEW_ME"]?["en"]?.state == .needsReview)
        #expect(table.terms["REVIEW_ME"]?["de"] == nil)
        // A key without localizations falls back to itself as the source value
        #expect(table.terms["EMPTY_KEY"]?["en"]?.value == "EMPTY_KEY")
        #expect(table.skippedPluralKeys.isEmpty)
    }

    @Test func readerSkipsAndReportsPluralKeys() throws {
        let pluralCatalog = #"""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "ITEM_COUNT" : {
              "localizations" : {
                "en" : {
                  "variations" : {
                    "plural" : {
                      "one" : { "stringUnit" : { "state" : "translated", "value" : "One item" } },
                      "other" : { "stringUnit" : { "state" : "translated", "value" : "%d items" } }
                    }
                  }
                }
              }
            }
          },
          "version" : "1.0"
        }
        """#
        let path = try writeFixture(pluralCatalog)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let table = try StringCatalogReader.table(atPath: path)
        #expect(table.skippedPluralKeys == ["ITEM_COUNT"])
        #expect(table.terms["ITEM_COUNT"] == nil)
    }

    @Test func serializerRoundTripsXcodeFormatting() throws {
        let object = try JSONSerialization.jsonObject(with: Self.fixture.data(using: .utf8)!) as! [String: Any]
        let serialized = XcodeStyleJSON.string(from: object) + "\n"
        #expect(serialized == Self.fixture)
    }

    @Test func writerInsertsNeedsReviewWithoutTouchingExistingEntries() throws {
        let path = try writeFixture()
        defer { try? FileManager.default.removeItem(atPath: path) }

        try StringCatalogWriter.add([.init(key: "REVIEW_ME", locale: "de", value: "Prüf mich")], toCatalogAtPath: path)

        let table = try StringCatalogReader.table(atPath: path)
        #expect(table.terms["REVIEW_ME"]?["de"]?.value == "Prüf mich")
        #expect(table.terms["REVIEW_ME"]?["de"]?.state == .needsReview)
        // Untouched parts survive byte-identically, including unknown fields
        let written = try String(contentsOfFile: path, encoding: .utf8)
        #expect(written.contains(#""extractionState" : "manual""#))
        #expect(written.contains(#""value" : "Hello %@!""#))
        #expect(written.hasSuffix("\n"))
    }

    @Test func writerNeverOverwritesExistingTranslations() throws {
        let path = try writeFixture()
        defer { try? FileManager.default.removeItem(atPath: path) }

        try StringCatalogWriter.add([.init(key: "GREETING", locale: "de", value: "ÜBERSCHRIEBEN")], toCatalogAtPath: path)

        let table = try StringCatalogReader.table(atPath: path)
        #expect(table.terms["GREETING"]?["de"]?.value == "Hallo")
    }
}
