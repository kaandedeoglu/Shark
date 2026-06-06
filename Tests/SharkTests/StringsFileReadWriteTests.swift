import Testing
import Foundation
@testable import SharkKit

struct StringsFileReadWriteTests {
    private func makeProject(localizations: [String: [String: String]]) throws -> (root: String, paths: [String]) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("shark-test-\(UUID().uuidString)").path
        var paths: [String] = []
        for (locale, entries) in localizations {
            let dir = root.appendingPathComponent("\(locale).lproj")
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("Localizable.strings")
            let contents = entries.map { "\"\($0.key)\" = \"\($0.value)\";" }.joined(separator: "\n")
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
            paths.append(path)
        }
        return (root, paths)
    }

    @Test func readerGroupsLocalesIntoOneTable() throws {
        let (root, paths) = try makeProject(localizations: [
            "en": ["GREETING": "Hello", "BYE": "Goodbye"],
            "de": ["GREETING": "Hallo"],
        ])
        defer { try? FileManager.default.removeItem(atPath: root) }

        let tables = try StringsFileReader.tables(forPaths: paths, sourceLocale: "en")

        #expect(tables.count == 1)
        let table = try #require(tables.first)
        #expect(table.name == "Localizable")
        #expect(table.locales == ["en", "de"])
        #expect(table.terms["GREETING"]?["de"]?.value == "Hallo")
        #expect(table.terms["BYE"]?["en"]?.value == "Goodbye")
        #expect(table.terms["BYE"]?["de"] == nil)
    }

    @Test func localeIsDerivedFromLprojFolder() {
        #expect(StringsFileReader.locale(forPath: "/x/de.lproj/Localizable.strings") == "de")
        #expect(StringsFileReader.locale(forPath: "/x/pt-BR.lproj/Localizable.strings") == "pt-BR")
        #expect(StringsFileReader.locale(forPath: "/x/Localizable.strings") == nil)
    }

    @Test func writerAppendsWithoutTouchingExistingContent() throws {
        let (root, paths) = try makeProject(localizations: ["de": ["GREETING": "Hallo"]])
        defer { try? FileManager.default.removeItem(atPath: root) }
        let path = paths[0]
        let originalContents = try String(contentsOfFile: path, encoding: .utf8)

        try StringsFileWriter.append([(key: "BYE", value: "Tschüss \"Welt\"\nZeile 2")], toFileAtPath: path)

        let written = try String(contentsOfFile: path, encoding: .utf8)
        #expect(written.hasPrefix(originalContents))
        #expect(written.contains("/* Added by shark translate — review before release */"))
        #expect(written.contains(#""BYE" = "Tschüss \"Welt\"\nZeile 2";"#))

        // The result must still be a valid .strings file
        let parsed = NSDictionary(contentsOfFile: path) as? [String: String]
        #expect(parsed?["BYE"] == "Tschüss \"Welt\"\nZeile 2")
        #expect(parsed?["GREETING"] == "Hallo")
    }
}
