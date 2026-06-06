import Testing
import Foundation
@testable import SharkKit

struct FrameworkTests {
    
    @Test func frameworkImportStatements() {
        #expect(Framework.uikit.importStatement == "import UIKit")
        #expect(Framework.appkit.importStatement == "import AppKit")
        #expect(Framework.swiftui.importStatement == "import SwiftUI")
    }
    
    @Test func frameworkRawValues() {
        #expect(Framework.uikit.rawValue == "uikit")
        #expect(Framework.appkit.rawValue == "appkit")
        #expect(Framework.swiftui.rawValue == "swiftui")
    }
    
    @Test func frameworkFromString() {
        #expect(Framework(rawValue: "uikit") == .uikit)
        #expect(Framework(rawValue: "appkit") == .appkit)
        #expect(Framework(rawValue: "swiftui") == .swiftui)
        #expect(Framework(rawValue: "invalid") == nil)
    }
}