import Foundation

private enum LocalizationValue: Comparable {
    enum InterpolationType {
        case uint
        case int
        case int64
        case double
        case string

        // Mirrors the historical mapping; conversions the codegen never
        // supported (%x, %e, …) stay ignored so generated code is unchanged
        init?(specifier: FormatSpecifier) {
            switch specifier.conversion {
                case "@":
                    self = .string
                case "d" where specifier.lengthModifier.hasPrefix("l"):
                    self = .int64
                case "d", "i":
                    self = .int
                case "u":
                    self = .uint
                case "f":
                    self = .double
                default:
                    return nil
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
                let escapedKey = key.swiftStringLiteralEscaped
                if interpolatedTypes.isEmpty == false {
                    result += interpolatedTypes.functionDeclaration(withName: name, key: escapedKey, indentLevel: indentLevel, options: options)
                } else {
                    result += #"\#(String.indent(indentLevel))\#(options.visibility) static var \#(name): String { return NSLocalizedString("\#(escapedKey)", bundle: bundle, comment: "") }"#
                }
        }
        return result
    }

    private static func interpolationTypes(forValue value: String) throws -> [InterpolationType] {
        FormatSpecifierParser.specifiers(in: value).compactMap(InterpolationType.init(specifier:))
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

            let stringCatalog: StringCatalog
            do {
                stringCatalog = try JSONDecoder().decode(StringCatalog.self, from: fileContents)
            } catch {
                // Some tools write raw newlines into .xcstrings values, producing invalid JSON — repair and retry
                guard let jsonString = String(data: fileContents, encoding: .utf8),
                      let fixedContents = fixMultilineStringsInJSON(jsonString).data(using: .utf8) else {
                    throw error
                }
                stringCatalog = try JSONDecoder().decode(StringCatalog.self, from: fixedContents)
            }

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

extension LocalizationEnumBuilder {
    /// Repairs .xcstrings JSON containing raw newlines inside string literals, which the JSON
    /// spec forbids. Only literal control characters are escaped — existing escape sequences,
    /// quotes, and backslashes pass through untouched, so valid JSON is returned unchanged.
    static func fixMultilineStringsInJSON(_ jsonString: String) -> String {
        var result = ""
        result.reserveCapacity(jsonString.count)
        var insideString = false
        var afterBackslash = false

        for character in jsonString {
            guard insideString else {
                if character == "\"" { insideString = true }
                result.append(character)
                continue
            }
            if afterBackslash {
                afterBackslash = false
                result.append(character)
                continue
            }
            switch character {
                case "\\":
                    afterBackslash = true
                    result.append(character)
                case "\"":
                    insideString = false
                    result.append(character)
                case "\n":
                    result.append("\\n")
                case "\r":
                    result.append("\\r")
                case "\t":
                    result.append("\\t")
                default:
                    result.append(character)
            }
        }
        return result
    }
}
