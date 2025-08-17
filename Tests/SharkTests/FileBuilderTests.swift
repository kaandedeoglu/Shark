import Testing
import Foundation
@testable import Shark

struct FileBuilderTests {
    
    @Test func frameworkImportStatements() {
        // Test framework import statement generation
        #expect(Framework.uikit.importStatement == "import UIKit")
        #expect(Framework.appkit.importStatement == "import AppKit") 
        #expect(Framework.swiftui.importStatement == "import SwiftUI")
    }
}