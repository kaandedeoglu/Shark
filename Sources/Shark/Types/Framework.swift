enum Framework: String {
    case uikit
    case appkit
    case swiftui

    var importStatement: String {
        let name: String
        switch self {
            case .uikit: name = "UIKit"
            case .appkit: name = "AppKit"
            case .swiftui: name = "SwiftUI"
        }
        return "import \(name)"
    }
}
