import Foundation

enum SharkEnumBuilder {
    static var topLevelEnumName = "Shark"
    static func sharkEnumString(forOptions options: Options) throws -> String {
        SharkEnumBuilder.topLevelEnumName = options.topLevelEnumName
        let resourcePaths = try XcodeProjectHelper(options: options).resourcePaths()
        
        let imagesString = try ImageEnumBuilder.imageEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "I")
        let colorsString = try ColorEnumBuilder.colorEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "C")
        let localizationsString = try LocalizationEnumBuilder.localizationsEnumString(forFilesAtPaths: resourcePaths.localizationPaths, topLevelName: "L")
        
        let declarations = [imagesString, colorsString, localizationsString].compactMap({ $0?.indented(withLevel: 1) }).joined(separator: "\n\n")
        
        return """
        public enum \(topLevelEnumName) {
            private class Custom {}
            static var bundle: Bundle { return Bundle(for: Custom.self) }
        \(declarations)
        }
        """
    }
}
