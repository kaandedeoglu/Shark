import Foundation

enum NestedValue<Asset: AssetType>: Equatable, Comparable {
    case value(propertyName: String, name: String)
    case namespace(name: String)

    func declaration(withBody body: String = "", indentLevel: Int) -> String {
        switch self {
        case let .value(propertyName, value):
            let valueDeclaration = Asset.declaration(forPropertyName: propertyName, value: value)
            return "\(String.indent(indentLevel))\(valueDeclaration)"
        case let .namespace(name):
            return #"""
            \#(String.indent(indentLevel))public enum \#(name) {
            \#(body)
            \#(String.indent(indentLevel))}

            """#
        }
    }

    static func <(lhs: NestedValue, rhs: NestedValue) -> Bool {
        switch(lhs, rhs) {
        case (let .namespace(leftName), let .namespace(rightName)),
             (let .value(leftName, _), let .value(rightName, _)):
            return leftName < rightName
        case (.namespace, .value):
            return true
        case (.value, .namespace):
            return false
        }
    }
}

extension NestedValue: SanitizableValue {
    var name: String {
        switch self {
        case let .namespace(name), let .value(name, _):
            return name
        }
    }

    func underscoringName() -> Self {
        switch self {
        case .value(let propertyName, let value):
            return .value(propertyName: propertyName.underscored, name: value)
        case .namespace(let name):
            return .namespace(name: name.underscored)
        }
    }
}

enum NestedEnumBuilder<Kind: AssetType> {
    static func enumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let assetPaths = try paths.flatMap { try FileManager.default.subpathsOfDirectory(atPath: $0).filter({ $0.pathExtension == Kind.extension  }) }
        guard assetPaths.isEmpty == false else { return nil }

        let rootNode: Node<NestedValue<Kind>> = Node(value: .namespace(name: topLevelName))

        for path in assetPaths {
            var pathComponents = path.pathComponents
            let name = pathComponents.removeLast().deletingPathExtension

            var pathNodes: [Node<NestedValue<Kind>>] = pathComponents.map { Node(value: .namespace(name: $0.propertyNameSanitized)) }
            pathNodes.append(Node(value: .value(propertyName: name.propertyNameSanitized, name: name)))

            rootNode.add(childrenRelatively: pathNodes)
        }

        rootNode.sort()
        rootNode.sanitize()

        var result = enumString(for: rootNode)
        result.removeLast()

        var lines = result.components(separatedBy: .newlines)
        if let lastNewlineIndex = lines.lastIndex(where: { $0.allSatisfy(\.isNewline) }) {
            lines.remove(at: lastNewlineIndex)
        }

        return lines.joined(separator: "\n")
    }

    private static func enumString(for node: Node<NestedValue<Kind>>, indentLevel: Int = 0) -> String {
        switch node.value {
        case .namespace:
            let childrenString = node.children.map { enumString(for: $0, indentLevel: indentLevel + 1) }
            return node.value.declaration(withBody: childrenString.joined(separator: "\n"), indentLevel: indentLevel)
        case .value:
            return node.value.declaration(indentLevel: indentLevel)
        }
    }
}
