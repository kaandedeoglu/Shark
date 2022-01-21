import Foundation

private struct ColorValue: Equatable, Comparable {
    let name: String
    
    func declaration(indentLevel: Int, framework: Framework) -> String {
        switch framework {
            case .uikit:
                return #"\#(String.indent(indentLevel))public static var \#(name.casenameSanitized): UIColor { return UIColor(named: "\#(name)", in: bundle, compatibleWith: nil)! }"#
            case .appkit:
                return #"\#(String.indent(indentLevel))public static var \#(name.casenameSanitized): NSColor { return NSColor(named: "\#(name)", bundle: bundle)! }"#
            case .swiftui:
                return #"\#(String.indent(indentLevel))public static var \#(name.casenameSanitized): Color { return Color("\#(name)", bundle: bundle) }"#
        }
    }

    static func <(lhs: ColorValue, rhs: ColorValue) -> Bool {
        return lhs.name < rhs.name
    }
}

enum ColorEnumBuilder {
    private enum Constants {
        static let colorSetExtension = "colorset"
    }
    
    static func colorEnumString(forFilesAtPaths paths: [String], topLevelName: String, options: Options) throws -> String? {
        let colorAssetPaths = try paths.flatMap { try FileManager.default.subpathsOfDirectory(atPath: $0).filter({ $0.pathExtension == Constants.colorSetExtension }) }
        guard colorAssetPaths.isEmpty == false else { return nil }

        var result = "public enum \(topLevelName) {\n"
        for name in colorAssetPaths.map({ $0.lastPathComponent.deletingPathExtension }).sorted() {
            result += ColorValue(name: name).declaration(indentLevel: 1, framework: options.framework)
            result += "\n"
        }
        
        result += "}"
        return result
    }
}
