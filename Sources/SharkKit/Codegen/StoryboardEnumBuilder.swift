import Foundation

private struct StoryboardValue: Equatable, Comparable {
    let name: String

    func declaration(indentLevel: Int, options: Options) -> String {
        switch options.framework {
            case .uikit:
                return #"\#(String.indent(indentLevel))\#(options.visibility) static var \#(name.propertyNameSanitized): UIStoryboard { return UIStoryboard(name: "\#(name)", bundle: bundle) }"#
            case .appkit:
                return #"\#(String.indent(indentLevel))\#(options.visibility) static var \#(name.propertyNameSanitized): NSStoryboard { return NSStoryboard(name: "\#(name)", bundle: bundle) }"#
            case .swiftui:
                return "" // there are no storyboards in the land of SwiftUI
        }
    }

    static func <(lhs: StoryboardValue, rhs: StoryboardValue) -> Bool {
        return lhs.name < rhs.name
    }
}

enum StoryboardBuilder {
    private enum Constants {
        static let storyboardExtension = "storyboard"
    }

    static func storyboardEnumString(forFilesAtPaths paths: [String], topLevelName: String, options: Options) throws -> String? {
        let storyboardPaths = Set(paths.map(\.lastPathComponent))

        guard storyboardPaths.isEmpty == false else { return nil }

        var result = "\(options.visibility) enum \(topLevelName) {\n"
        for name in storyboardPaths.map({ $0.deletingPathExtension }).sorted() {
            result += StoryboardValue(name: name).declaration(indentLevel: 1, options: options)
            result += "\n"
        }

        result += "}"

        return result
    }
}
