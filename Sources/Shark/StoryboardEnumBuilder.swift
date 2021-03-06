import Foundation

private struct StoryboardValue: Equatable, Comparable {
    let name: String

    func declaration(indentLevel: Int) -> String {
        return #"\#(String.indent(indentLevel))public static var \#(name.casenameSanitized): UIStoryboard { return UIStoryboard(name: "\#(name)", bundle: bundle) }"#
    }

    static func <(lhs: StoryboardValue, rhs: StoryboardValue) -> Bool {
        return lhs.name < rhs.name
    }
}

enum StoryboardBuilder {
    private enum Constants {
        static let storyboardExtension = "storyboard"
    }

    static func storyboardEnumString(forFilesAtPaths paths: [String], topLevelName: String) throws -> String? {
        let storyboardPaths = Set(paths.map(\.lastPathComponent))

        guard storyboardPaths.isEmpty == false else { return nil }

        var result = "public enum \(topLevelName) {\n"
        for name in storyboardPaths.map({ $0.deletingPathExtension }).sorted() {
            result += StoryboardValue(name: name).declaration(indentLevel: 1)
            result += "\n"
        }

        result += "}"

        return result
    }
}
