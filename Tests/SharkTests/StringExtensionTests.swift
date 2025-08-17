import Testing
import Foundation
@testable import Shark

struct StringExtensionTests {
    
    @Test func indentMethod() {
        #expect(String.indent(0) == "")
        #expect(String.indent(1) == "    ")
        #expect(String.indent(2) == "        ")
        #expect(String.indent(3) == "            ")
    }
    
    @Test func propertyNameSanitized() {
        // Test basic sanitization
        #expect("validName".propertyNameSanitized == "validName")
        #expect("with-dashes".propertyNameSanitized == "with_dashes")
        
        // Test Swift keywords
        #expect("class".propertyNameSanitized == "_class")
        #expect("struct".propertyNameSanitized == "_struct")
        #expect("enum".propertyNameSanitized == "_enum")
        #expect("func".propertyNameSanitized == "_func")
        #expect("var".propertyNameSanitized == "_var")
        #expect("let".propertyNameSanitized == "_let")
        
        // Test empty string handling
        #expect("".propertyNameSanitized == "")
    }
    
    @Test func underscored() {
        #expect("CamelCase".underscored == "_CamelCase")
        #expect("XMLHttpRequest".underscored == "_XMLHttpRequest")
        #expect("HTTPResponse".underscored == "_HTTPResponse")
        #expect("URLSessionTask".underscored == "_URLSessionTask")
        #expect("simple".underscored == "_simple")
        #expect("ALLCAPS".underscored == "_ALLCAPS")
    }
    
    @Test func indentedWithLevel() {
        let text = "line1\nline2\nline3"
        let expected = "    line1\n    line2\n    line3"
        #expect(text.indented(withLevel: 1) == expected)
        
        let singleLine = "single line"
        #expect(singleLine.indented(withLevel: 2) == "        single line")
    }
    
    @Test func mapLines() {
        let text = "line1\nline2\nline3"
        let result = text.mapLines { ">>> \($0)" }
        let expected = ">>> line1\n>>> line2\n>>> line3"
        #expect(result == expected)
        
        let singleLine = "single"
        #expect(singleLine.mapLines { $0.uppercased() } == "SINGLE")
    }
    
    @Test func appendingPathComponent() {
        #expect("/path/to".appendingPathComponent("file.txt") == "/path/to/file.txt")
        #expect("/path/to/".appendingPathComponent("file.txt") == "/path/to/file.txt")
        #expect("relative".appendingPathComponent("file.txt") == "relative/file.txt")
        #expect("".appendingPathComponent("file.txt") == "file.txt")
    }
    
    @Test func pathExtension() {
        #expect("file.txt".pathExtension == "txt")
        #expect("image.png".pathExtension == "png")
        #expect("archive.tar.gz".pathExtension == "gz")
        #expect("noextension".pathExtension == "")
        #expect("".pathExtension == "")
        #expect(".hidden".pathExtension == "")
    }
}