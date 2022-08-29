import Foundation

private enum DataAssetValue: Equatable, Comparable {
    case dataAsset(caseName: String, value: String)
    case namespace(name: String)

    func declaration(withBody body: String = "", indentLevel: Int) throws -> String {
        switch self {
        case .dataAsset(let name, let value):
            return #"\#(String.indent(indentLevel))public static var \#(name): Data { return NSDataAsset(name: "\#(value)", bundle: bundle)!.data }"#
        case .namespace(let name):
            return #"""
            \#(String.indent(indentLevel))public enum \#(name): CaseIterable {
            \#(body)
            \#(String.indent(indentLevel))}

            """#
        }
    }

    static func <(lhs: DataAssetValue, rhs: DataAssetValue) -> Bool {
        switch (lhs, rhs) {
        case (.namespace(let leftName), .namespace(let rightName)),
             (.dataAsset(_, let leftName), .dataAsset(_, let rightName)):
            return leftName < rightName
        case (.namespace, .dataAsset):
            return true
        case (.dataAsset, .namespace):
            return false
        }
    }
}

extension DataAssetValue: SanitizableValue {
    var name: String {
        switch self {
        case .namespace(let name), .dataAsset(let name, _):
            return name
        }
    }

    func underscoringName() -> Self {
        switch self {
        case .dataAsset(let caseName, let value):
            return .dataAsset(caseName: caseName.underscored, value: value)
        case .namespace(let name):
            return .namespace(name: name.underscored)
        }
    }
}

enum DataAssetEnumBuilder {
    private enum Constants {
        static let dataAssetExtension = "dataset"
    }
    static func dataAssetEnumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let dataAssetPaths = try paths.flatMap { try FileManager.default.subpathsOfDirectory(atPath: $0).filter({ $0.pathExtension == Constants.dataAssetExtension }) }
        guard dataAssetPaths.isEmpty == false else { return nil }
        
        let rootNode: Node<DataAssetValue> = Node(value: .namespace(name: topLevelName))
        
        for path in dataAssetPaths {
            var pathComponents = path.pathComponents
            let name = pathComponents.removeLast().deletingPathExtension
            
            var pathNodes: [Node<DataAssetValue>] = pathComponents.map { Node(value: .namespace(name: $0.casenameSanitized)) }
            pathNodes.append(Node(value: .dataAsset(caseName: name.casenameSanitized, value: name)))
            
            rootNode.add(childrenRelatively: pathNodes)
        }
        
        rootNode.sort()
        rootNode.sanitize()
        
        var result = try enumString(for: rootNode)
        result.removeLast()
        return result
    }
    
    private static func enumString(for node: Node<DataAssetValue>, indentLevel: Int = 0) throws -> String {
        switch node.value {
        case .namespace:
            let childrenString = try node.children.map { try enumString(for: $0, indentLevel: indentLevel + 1) }
            return try node.value.declaration(withBody: childrenString.joined(separator: "\n"), indentLevel: indentLevel)
        case .dataAsset:
            return try node.value.declaration(indentLevel: indentLevel)
        }
    }
}
