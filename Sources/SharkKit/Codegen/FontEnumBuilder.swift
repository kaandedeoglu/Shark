import CoreGraphics
import Foundation

private struct FontValue: Equatable, Comparable {
    let methodName: String
    let fontName: String

    func declaration(indentLevel: Int, options: Options) -> String {
        switch options.framework {
            case .uikit:
                return #"\#(String.indent(indentLevel))\#(options.visibility) static func \#(methodName)(ofSize size: CGFloat) -> UIFont { return UIFont(name: "\#(fontName)", size: size)! }"#
            case .appkit:
                return #"\#(String.indent(indentLevel))\#(options.visibility) static func \#(methodName)(ofSize size: CGFloat) -> NSFont { return NSFont(name: "\#(fontName)", size: size)! }"#
            case .swiftui:
                return #"\#(String.indent(indentLevel))\#(options.visibility) static func \#(methodName)(ofSize size: CGFloat) -> Font { return Font.custom("\#(fontName)", size: size) }"#
        }
    }

    static func <(lhs: FontValue, rhs: FontValue) -> Bool {
        lhs.methodName < rhs.methodName
    }
}

enum FontEnumBuilder {
    static func fontsEnumString(forFilesAtPaths paths: [String], topLevelName: String, options: Options) throws -> String? {
        let fontValues: [FontValue] = paths.compactMap { path in
            guard
                let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                let font = CGDataProvider(data: data as CFData).flatMap(CGFont.init),
                let fullName = font.fullName as String?,
                let postScriptName = font.postScriptName as String? else { return nil }

            let sanitized = fullName
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            var components = sanitized.split(separator: " ")
            let first = components.removeFirst().lowercased()
            let rest = components.map { $0.capitalized }
            let methodName = ([first] + rest).joined()

            return FontValue(methodName: methodName.propertyNameSanitized,
                             fontName: postScriptName)
        }

        guard fontValues.isEmpty == false else { return nil }

        var result = """
        \(options.visibility) enum \(topLevelName): CaseIterable {

        """

        for font in fontValues.sorted() {
            result += font.declaration(indentLevel: 1, options: options)
            result += "\n"
        }

        result += "}"
        return result
    }
}
