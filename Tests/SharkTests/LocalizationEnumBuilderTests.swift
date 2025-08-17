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