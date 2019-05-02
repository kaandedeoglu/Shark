import Foundation

private enum ColorValue: Equatable, Comparable {
    case color(name: String)
    
    func declaration(indentLevel: Int) -> String {
        switch self {
        case .color(let name):
            return #"\#(String(indentLevel: indentLevel))public static var \#(name.casenameSanitized): UIColor { return UIColor(named: "\#(name)")! }"#
        }
    }
    
    static func <(lhs: ColorValue, rhs: ColorValue) -> Bool {
        switch (lhs, rhs) {
        case (.color(let leftName), .color(let rightName)):
            return leftName < rightName
        }
    }
}

enum ColorEnumBuilder {
    private enum Constants {
        static let colorSetExtension = "colorset"
    }
    
    static func colorEnumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let colorAssetPaths = try paths.flatMap { try FileManager.default.subpathsOfDirectory(atPath: $0).filter({ $0.pathExtension == Constants.colorSetExtension }) }
        guard colorAssetPaths.isEmpty == false else { return nil }
        
        var result = """
public enum \(topLevelName) {

"""
        for name in colorAssetPaths.map({ $0.lastPathComponent.deletingPathExtension }).sorted() {
            result += ColorValue.color(name: name).declaration(indentLevel: 1)
            result += "\n"
        }
        
        result += "}"
        return result
    }
}
