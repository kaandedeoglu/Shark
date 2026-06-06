import Testing
import Foundation
@testable import SharkKit

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
    
    @Test func multilineStringParsingWithXCStrings() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let xcstringsFile = tempDir.appendingPathComponent("test.xcstrings")
        
        // Create a string catalog with multiline strings - testing both escaped and actual multiline
        let multilineXCStringsContent = """
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Simple Key" : {
              "localizations" : {
                "en" : {
                  "stringUnit" : {
                    "state" : "translated",
                    "value" : "Simple value"
                  }
                }
              }
            },
            "Multiline Message" : {
              "localizations" : {
                "en" : {
                  "stringUnit" : {
                    "state" : "translated",
                    "value" : "This is the first line\\nThis is the second line\\nThis is the third line"
                  }
                }
              }
            },
            "Welcome Text" : {
              "localizations" : {
                "en" : {
                  "stringUnit" : {
                    "state" : "translated",
                    "value" : "Welcome to our app!\\n\\nPlease read our terms:\\n- Privacy policy\\n- User agreement\\n\\nThank you!"
                  }
                }
              }
            }
          },
          "version" : "1.0"
        }
        """
        
        try multilineXCStringsContent.write(to: xcstringsFile, atomically: true, encoding: .utf8)
        
        // Test parsing StringCatalog directly first
        let url = URL(fileURLWithPath: xcstringsFile.path)
        let fileContents = try Data(contentsOf: url)
        let stringCatalog = try JSONDecoder().decode(StringCatalog.self, from: fileContents)
        
        // Verify string catalog parsing works
        #expect(stringCatalog.sourceLanguage == "en")
        #expect(stringCatalog.strings.count == 3)
        
        let simpleEntry = stringCatalog.strings["Simple Key"]
        #expect(simpleEntry != nil)
        #expect(simpleEntry?.localizations?["en"]?.stringUnit?.value == "Simple value")
        
        let multilineEntry = stringCatalog.strings["Multiline Message"]
        #expect(multilineEntry != nil)
        let multilineValue = multilineEntry?.localizations?["en"]?.stringUnit?.value
        
        // The issue: JSON decoder automatically converts escaped \n to actual newlines
        #expect(multilineValue == "This is the first line\nThis is the second line\nThis is the third line")
        
        // The multiline string contains actual newlines, not escaped ones
        #expect(multilineValue?.contains("\n") == true)
        #expect(multilineValue?.contains("\\n") == false)
        
        // The problem is that these multiline strings should be properly escaped 
        // when generating Swift code comments and string literals
        let lines = multilineValue?.components(separatedBy: "\n")
        #expect(lines?.count == 3)
        #expect(lines?[0] == "This is the first line")
        #expect(lines?[1] == "This is the second line")
        #expect(lines?[2] == "This is the third line")
        
        // Clean up
        try? FileManager.default.removeItem(at: xcstringsFile)
    }
    
    @Test func fixMultilineStringsInJSONFunction() throws {
        // Test the fix function directly
        let problematicJSON = """
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Welcome Message" : {
              "localizations" : {
                "en" : {
                  "stringUnit" : {
                    "state" : "translated",
                    "value" : "Welcome to our amazing app!

        Please take a moment to read our:
        • Privacy Policy
        • Terms of Service

        Thank you for joining us!"
                  }
                }
              }
            }
          },
          "version" : "1.0"
        }
        """
        
        // This should fail without the fix
        #expect(throws: Error.self) {
            _ = try JSONDecoder().decode(StringCatalog.self, from: problematicJSON.data(using: .utf8)!)
        }
        
        // Apply the fix
        let fixedJSON = LocalizationEnumBuilder.fixMultilineStringsInJSON(problematicJSON)
        
        // Now it should parse successfully
        let stringCatalog = try JSONDecoder().decode(StringCatalog.self, from: fixedJSON.data(using: .utf8)!)
        
        let welcomeEntry = stringCatalog.strings["Welcome Message"]
        #expect(welcomeEntry != nil)
        let welcomeValue = welcomeEntry?.localizations?["en"]?.stringUnit?.value
        
        // The multiline content should be preserved
        #expect(welcomeValue?.contains("Welcome to our amazing app!") == true)
        #expect(welcomeValue?.contains("Privacy Policy") == true)
        #expect(welcomeValue?.contains("\n") == true)
        
        // Check that it properly escaped the newlines in the fixed JSON
        #expect(fixedJSON.contains("\\n"))
        #expect(!fixedJSON.contains("value\" : \"Welcome to our amazing app!\n"))
    }

    // Locks the generated signatures while the specifier parsing is shared
    // with lint/translate — codegen output must not change
    @Test func interpolationFunctionGeneration() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let stringsFile = tempDir.appendingPathComponent("interpolation-test.strings")
        defer { try? FileManager.default.removeItem(at: stringsFile) }

        let content = #"""
        "Items_COUNT_LABEL" = "%d items of %@";
        "Money_AMOUNT" = "%.2f total";
        "Big_COUNT" = "%ld entries";
        "Unsigned_COUNT" = "%u tries";
        "Plain_TITLE" = "Hello";
        "Percent_LABEL" = "100%% done";
        """#
        try content.write(to: stringsFile, atomically: true, encoding: .utf8)

        let options = try Options.parse(["dummy.xcodeproj", "dummy.swift"])
        let result = try #require(try LocalizationEnumBuilder.localizationsEnumString(
            forFilesAtPaths: [stringsFile.path],
            topLevelName: "L",
            options: options
        ))

        #expect(result.contains("func Items_COUNT_LABEL(_ value1: Int,_ value2: String) -> String"))
        #expect(result.contains("func Money_AMOUNT(_ value1: Double) -> String"))
        #expect(result.contains("func Big_COUNT(_ value1: Int64) -> String"))
        #expect(result.contains("func Unsigned_COUNT(_ value1: UInt) -> String"))
        #expect(result.contains("static var Plain_TITLE: String"))
        #expect(result.contains("static var Percent_LABEL: String"))
    }
}