import Foundation

private struct FontValue: Equatable, Comparable {
    let methodName: String
    let fontName: String

    func declaration(indentLevel: Int) -> String {
        #"\#(String.indent(indentLevel))public static func \#(methodName)(ofSize size: CGFloat) -> UIFont { return UIFont(name: "\#(fontName)", size: size)! }"#
    }

    static func <(lhs: FontValue, rhs: FontValue) -> Bool {
        lhs.methodName < rhs.methodName
    }
}

enum FontEnumBuilder {
    static func fontsEnumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let fontValues: [FontValue] = paths.compactMap { path in
            guard
                let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                let font = CGDataProvider(data: data as CFData).flatMap(CGFont.init),
                let fullName = font.fullName as String?,
                let postScriptName = font.postScriptName as String? else { return nil }

            var components = fullName.split(separator: " ")
            let first = components.removeFirst().lowercased()
            let rest = components.map { $0.capitalized }
            let methodName = ([first] + rest).joined()

            return FontValue(methodName: methodName,
                             fontName: postScriptName)
        }

        guard fontValues.isEmpty == false else { return nil }

        var result = """
        public enum \(topLevelName) {

        """

        for font in fontValues.sorted() {
            result += font.declaration(indentLevel: 1)
            result += "\n"
        }

        result += "}"
        return result
    }
}
