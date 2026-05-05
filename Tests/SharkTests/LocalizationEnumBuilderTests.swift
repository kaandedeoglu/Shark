import Testing
import Foundation
@testable import Shark

struct LocalizationEnumBuilderTests {
    
    @Test func multilineStringParsingWithNSDictionary() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let stringsFile = tempDir.appendingPathComponent("test.strings")
        
        let multilineContent = """
        /* Simple string */
        "SIMPLE_KEY" = "Simple value";
        
        /* Multiline with escaped newlines */
        "MULTILINE_ESCAPED" = "Line one\\nLine two\\nLine three";
        
        /* Multiline with actual line breaks */
        "MULTILINE_LITERAL" = "This is the first line
        This is the second line
        This is the third line";
        
        /* Complex multiline content */
        "WELCOME_MESSAGE" = "Welcome to our app!
        
        Please read our terms:
        - Privacy policy
        - User agreement
        
        Thank you!";
        """
        
        try multilineContent.write(to: stringsFile, atomically: true, encoding: .utf8)
        
        // Test that NSDictionary can parse multiline strings correctly
        let dict = NSDictionary(contentsOfFile: stringsFile.path) as? [String: String]
        
        #expect(dict != nil)
        let parsedDict = dict!
        
        #expect(parsedDict["SIMPLE_KEY"] == "Simple value")
        #expect(parsedDict["MULTILINE_ESCAPED"] == "Line one\nLine two\nLine three")
        #expect(parsedDict["MULTILINE_LITERAL"]?.contains("This is the first line") == true)
        #expect(parsedDict["MULTILINE_LITERAL"]?.contains("This is the second line") == true)
        #expect(parsedDict["WELCOME_MESSAGE"]?.contains("Welcome to our app!") == true)
        #expect(parsedDict["WELCOME_MESSAGE"]?.contains("Privacy policy") == true)
        
        // Clean up
        try? FileManager.default.removeItem(at: stringsFile)
    }
    
    @Test func multilineXcStringsKeyEscaping() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let catalogFile = tempDir.appendingPathComponent("multiline.xcstrings")

        let catalog = #"""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Welcome!\nTap to continue." : {
              "localizations" : {
                "en" : { "stringUnit" : { "state" : "translated", "value" : "Welcome!\nTap to continue." } }
              }
            },
            "He said \"hi\"" : {
              "localizations" : {
                "en" : { "stringUnit" : { "state" : "translated", "value" : "He said \"hi\"" } }
              }
            },
            "Use %@ to login" : {
              "localizations" : {
                "en" : { "stringUnit" : { "state" : "translated", "value" : "Use %@ to login" } }
              }
            }
          },
          "version" : "1.0"
        }
        """#

        try catalog.write(to: catalogFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: catalogFile) }

        let options = try Options.parse(["dummy.xcodeproj", "dummy.swift"])
        let result = try LocalizationEnumBuilder.localizationsEnumString(
            forFilesAtPaths: [catalogFile.path],
            topLevelName: "L",
            options: options
        )

        let output = try #require(result)

        // Keys with embedded newlines, quotes, and backslashes must be escaped so the
        // generated Swift string literal stays well-formed.
        #expect(output.contains(#""Welcome!\nTap to continue.""#))
        #expect(output.contains(#""He said \"hi\"""#))

        // Format-specifier keys should also round-trip into the function variant unchanged.
        #expect(output.contains(#""Use %@ to login""#))

        // The raw, unescaped newline must never appear inside a generated string literal.
        let lines = output.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            // Count unescaped quotes; an odd count means a literal that crossed the line boundary.
            var unescapedQuotes = 0
            var escaped = false
            for char in line {
                if escaped {
                    escaped = false
                    continue
                }
                if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    unescapedQuotes += 1
                }
            }
            #expect(unescapedQuotes.isMultiple(of: 2), "Line \(i) has unbalanced quotes: \(line)")
        }
    }

    @Test func invalidStringsFileHandling() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let invalidFile = tempDir.appendingPathComponent("invalid.strings")
        
        // Create invalid file
        try "invalid content without proper format".write(to: invalidFile, atomically: true, encoding: .utf8)
        
        // Test that NSDictionary returns nil for invalid files
        let dict = NSDictionary(contentsOfFile: invalidFile.path) as? [String: String]
        #expect(dict == nil)
        
        // Clean up
        try? FileManager.default.removeItem(at: invalidFile)
    }
}