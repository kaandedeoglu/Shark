import Foundation

enum NestedValue<Asset: AssetType>: Equatable, Comparable {
    case value(propertyName: String, name: String)
    case namespace(name: String)

    func declaration(withBody body: String = "", indentLevel: Int, options: Options) -> String {
        switch self {
            case let .value(propertyName, value):
                let valueDeclaration = Asset.declaration(forPropertyName: propertyName, value: value, options: options)
                return "\(String.indent(indentLevel))\(valueDeclaration)"
            case let .namespace(name):
                return #"""
            \#(String.indent(indentLevel))\#(options.visibility) enum \#(name): CaseIterable {
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

struct AssetCatalogue {

    let path: String
    let items: [String]

    init?(path: String, ext: String) {
        self.path = path
        guard !path.hasSuffix("Preview Assets.xcassets") else { return nil }
        guard let items = try? FileManager.default.subpathsOfDirectory(atPath: path).filter({ $0.pathExtension == ext }) else { return nil }
        guard !items.isEmpty else { return nil }
        self.items = items
    }
}

enum NestedEnumBuilder<Kind: AssetType> {
    static func enumString(forFilesAtPaths paths: [String], topLevelName: String, options: Options) throws -> String? {

        let assetCatalogues = paths.compactMap { AssetCatalogue(path: $0, ext: Kind.extension)}
        let rootNode: Node<NestedValue<Kind>> = Node(value: .namespace(name: topLevelName))

        for catalogue in assetCatalogues {
            for path in catalogue.items {

                var pathComponents = path.pathComponents

                if pathComponents.count > 1 {
                    // nested, so we have to traverse the folders for all Contents.json files
                    var fullPathToComponent = catalogue.path
                    let components = pathComponents.dropLast()
                    for (componentIndex, component) in components.enumerated() {
                        fullPathToComponent = fullPathToComponent.appendingPathComponent(component)
                        let pathToContentsJson = fullPathToComponent.appendingPathComponent("Contents.json")
                        let contents = try String(contentsOfFile: pathToContentsJson)
                        if !contents.localizedCaseInsensitiveContains(#""provides-namespace" : true"#) {
                            // this component does not provide a namespace, hence mark for removal
                            pathComponents[componentIndex] = ""
                        }
                    }
                    // remove the components where namespace is not requested
                    pathComponents = pathComponents.filter { !$0.isEmpty }
                }
                let name = pathComponents.joined(separator: "/").deletingPathExtension
                let property = pathComponents.removeLast().deletingPathExtension

                var pathNodes = pathComponents
                    .map(\.propertyNameSanitized)
                    .map(NestedValue<Kind>.namespace(name:))
                    .map(Node.init)
                pathNodes.append(Node(value: .value(propertyName: property.propertyNameSanitized, name: name)))

                rootNode.add(childrenRelatively: pathNodes)
            }
        }

        rootNode.sort()
        rootNode.sanitize()

        var result = enumString(for: rootNode, options: options)
        result.removeLast()

        var lines = result.components(separatedBy: .newlines)
        if let lastNewlineIndex = lines.lastIndex(where: { $0.allSatisfy(\.isNewline) }) {
            lines.remove(at: lastNewlineIndex)
        }

        return lines.joined(separator: "\n")
    }

    private static func enumString(for node: Node<NestedValue<Kind>>, indentLevel: Int = 0, options: Options) -> String {
        switch node.value {
            case .namespace:
                let childrenString = node.children.map { enumString(for: $0, indentLevel: indentLevel + 1, options: options) }
                return node.value.declaration(withBody: childrenString.joined(separator: "\n"), indentLevel: indentLevel, options: options)
            case .value:
                return node.value.declaration(indentLevel: indentLevel, options: options)
        }
    }
}

