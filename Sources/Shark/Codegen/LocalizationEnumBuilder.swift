import Foundation

private enum LocalizationValue: Comparable {
    enum InterpolationType {
        case uint
        case int
        case int64
        case double
        case string

        init(value: String) {
            if value.contains("ld") {
                self = .int64
            } else if value.contains("d") || value.contains("i") {
                self = .int
            } else if value.contains("u") {
                self = .uint
            } else if value.contains("f") {
                self = .double
            } else {
                self = .string
            }
        }

        var typeName: String {
            switch self {
                case .uint:
                    return "UInt"
                case .int:
                    return "Int"
                case .int64:
                    return "Int64"
                case.double:
                    return "Double"
                case .string:
                    return "String"
            }
        }
    }

    case namespace(name: String)
    case localization(name: String, key: String, value: String)

    static func <(lhs: LocalizationValue, rhs: LocalizationValue) -> Bool {
        switch (lhs, rhs) {
            case (.namespace, .localization):
                return true
            case (.localization, .namespace):
                return false
            case let (.namespace(leftName), .namespace(rightName)),
                let (.localization(leftName, _, _), .localization(rightName, _, _)):
                return leftName < rightName
        }
    }

    func declaration(withBody body: String = "", indentLevel: Int, options: Options) throws -> String {
        var result = ""
        switch self {
            case .namespace(let name):
                result += #"""
            \#(String.indent(indentLevel))\#(options.visibility) enum \#(name) {
            \#(body)
            \#(String.indent(indentLevel))}
            """#
            case .localization(let name, let key, let value):
                let translationComment = value.mapLines { "/// \($0)" }
                result += """
            \(translationComment.indented(withLevel: indentLevel))
            
            """

                let interpolatedTypes = try LocalizationValue.interpolationTypes(forValue: value)
                if interpolatedTypes.isEmpty == false {
                    result += interpolatedTypes.functionDeclaration(withName: name, key: key, indentLevel: indentLevel, options: options)
                } else {
                    result += #"\#(String.indent(indentLevel))\#(options.visibility) static var \#(name): String { return NSLocalizedString("\#(key)", bundle: bundle, comment: "") }"#
                }
        }
        return result
    }

    private static func interpolationTypes(forValue value: String) throws -> [InterpolationType] {
        let regex = try NSRegularExpression(pattern: "%([0-9]*.[0-9]*(d|i|u|f|ld)|(\\d\\$)?@|d|i|u|f|ld)", options: [])

        let results = regex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count))
        return results.map { (value as NSString).substring(with: $0.range) }.map(InterpolationType.init)
    }
}

extension LocalizationValue: SanitizableValue {
    var name: String {
        switch self {
            case .namespace(let name), .localization(let name, _, _):
                return name
        }
    }

    func underscoringName() -> Self {
        switch self {
            case .localization(let name, let key, let value):
                return .localization(name: name.underscored, key: key, value: value)
            case .namespace(let name):
                return .namespace(name: name.underscored)
        }
    }
}

enum LocalizationBuilderError: LocalizedError {
    case invalidLocalizableStringsFile(path: String)

    var errorDescription: String? {
        switch self {
            case .invalidLocalizableStringsFile(let path):
                return "Invalid .strings file at \(path)"
        }
    }
}

enum LocalizationEnumBuilder {

    static func localizationsEnumString(forFilesAtPaths paths: [String], topLevelName: String, options: Options) throws -> String? {

        let paths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        // We now support both `.strings` and `.xcstrings` files.
        let stringsPaths = paths.filter { $0.hasSuffix(".strings") }
        let xcstringsPaths = paths.filter { $0.hasSuffix(".xcstrings") }

        let stringsDictionaries = try stringsPaths.compactMap { path -> [String: String]? in
            guard let termsDictionary = NSDictionary(contentsOfFile: path) as? [String: String] else {
                throw LocalizationBuilderError.invalidLocalizableStringsFile(path: path)
            }
            return termsDictionary
        }

        let xcstringsDictionaries = try xcstringsPaths.compactMap { path -> [String: String]? in
            let url = URL(fileURLWithPath: path)
            let fileContents = try Data(contentsOf: url)
            let stringCatalog = try JSONDecoder().decode(StringCatalog.self, from: fileContents)

            var terms: [String: String] = [:]
            for (string, entry) in stringCatalog.strings {
                guard let localizations = entry.localizations,
                      let sourceLocalization = localizations[stringCatalog.sourceLanguage],
                      let value = sourceLocalization.stringUnit?.value else {
                    terms[string] = string
                    continue
                }
                terms[string] = value
            }
            return terms
        }

        let termsDictionaries = stringsDictionaries + xcstringsDictionaries
        guard termsDictionaries.isEmpty == false else { return nil }

        let rootNode = Node(value: LocalizationValue.namespace(name: topLevelName))

        for termsDictionary in termsDictionaries {
            for (name, value) in termsDictionary {
                var parts = name.split(separator: options.separator)

                guard parts.isEmpty == false else { continue }

                let lastComponent = parts.removeLast()
                let variableName = LocalizationValue.localization(name: String(lastComponent).propertyNameSanitized, key: name, value: value)
                var namespaces = parts.map({ LocalizationValue.namespace(name: String($0).propertyNameSanitized) })
                namespaces.append(variableName)
                rootNode.add(childrenRelatively: namespaces.map(Node.init))
            }
        }

        rootNode.sort()
        rootNode.sanitize()
        let result = try localizationEnumString(for: rootNode, options: options)
        return result
    }

    private static func localizationEnumString(for node: Node<LocalizationValue>, indentLevel: Int = 0, options: Options) throws -> String {
        switch node.value {
            case .namespace:
                let childrenString = try node.children.map { try localizationEnumString(for: $0, indentLevel: indentLevel + 1, options: options) }
                return try node.value.declaration(withBody: childrenString.joined(separator: "\n\n"), indentLevel: indentLevel, options: options)
            case .localization:
                return try node.value.declaration(indentLevel: indentLevel, options: options)
        }
    }
}

extension Array where Element == LocalizationValue.InterpolationType {
    func functionDeclaration(withName name: String, key: String, indentLevel: Int, options: Options) -> String {
        let variableName = "value"
        let arguments = zip((1...count), self).map { tuple -> String in
            let (idx, interpolationType) = tuple
            return "_ \(variableName)\(idx): \(interpolationType.typeName)"
        }
        let argumentsString = arguments.joined(separator: ",")
        let formatValuesString = (1...count).map { "\(variableName)\($0)"}.joined(separator: ", ")

        return #"""
        \#(String.indent(indentLevel))\#(options.visibility) static func \#(name)(\#(argumentsString)) -> String {
        \#(String.indent(indentLevel + 1))return String(format: NSLocalizedString("\#(key)", bundle: bundle, comment: ""), \#(formatValuesString))
        \#(String.indent(indentLevel))}
        """#
    }
}
