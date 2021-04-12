import Foundation

private enum ImageValue: Equatable, Comparable {
    case image(caseName: String, value: String)
    case namespace(name: String)
    
    func declaration(withBody body: String = "", indentLevel: Int) throws -> String {
        switch self {
        case .image(let name, let value):
            return #"\#(String.indent(indentLevel))public static var \#(name): UIImage { return UIImage(named:"\#(value)", in: bundle, compatibleWith: nil)! }"#
        case .namespace(let name):
            return #"""
            \#(String.indent(indentLevel))public enum \#(name) {
            \#(body)
            \#(String.indent(indentLevel))}
            
            """#
        }
    }
    
    static func <(lhs: ImageValue, rhs: ImageValue) -> Bool {
        switch (lhs, rhs) {
        case (.namespace(let leftName), .namespace(let rightName)),
             (.image(_, let leftName), .image(_, let rightName)):
            return leftName < rightName
        case (.namespace, .image):
            return true
        case (.image, .namespace):
            return false
        }
    }
}

extension ImageValue: SanitizableValue {
    var name: String {
        switch self {
        case .namespace(let name), .image(let name, _):
            return name
        }
    }

    func underscoringName() -> Self {
        switch self {
        case .image(let caseName, let value):
            return .image(caseName: caseName.underscored, value: value)
        case .namespace(let name):
            return .namespace(name: name.underscored)
        }
    }
}

enum ImageEnumBuilder {
    private enum Constants {
        static let imageSetExtension = "imageset"
    }
    
    static func imageEnumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let imageAssetPaths = try paths.flatMap { try FileManager.default.subpathsOfDirectory(atPath: $0).filter({ $0.pathExtension == Constants.imageSetExtension }) }
        guard imageAssetPaths.isEmpty == false else { return nil }
        
        let rootNode: Node<ImageValue> = Node(value: .namespace(name: topLevelName))
        
        for path in imageAssetPaths {
            var pathComponents = path.pathComponents
            let name = pathComponents.removeLast().deletingPathExtension
            
            var pathNodes: [Node<ImageValue>] = pathComponents.map { Node(value: .namespace(name: $0.casenameSanitized)) }
            pathNodes.append(Node(value: .image(caseName: name.casenameSanitized, value: name)))
            
            rootNode.add(childrenRelatively: pathNodes)
        }
        
        rootNode.sort()
        rootNode.sanitize()

        var result = try enumString(for: rootNode)
        result.removeLast()
        return result
    }
    
    private static func enumString(for node: Node<ImageValue>, indentLevel: Int = 0) throws -> String {
        switch node.value {
        case .namespace:
            let childrenString = try node.children.map { try enumString(for: $0, indentLevel: indentLevel + 1) }
            return try node.value.declaration(withBody: childrenString.joined(separator: "\n"), indentLevel: indentLevel)
        case .image:
            return try node.value.declaration(indentLevel: indentLevel)
        }
    }
}
