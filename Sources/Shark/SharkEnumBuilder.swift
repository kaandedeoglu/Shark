import Foundation

enum SharkEnumBuilder {
    static func sharkEnumString(forParseResult parseResult: Parser.Result) throws -> String {
        let resourcePaths = try XcodeProjectHelper(parseResult: parseResult).resourcePaths()
        
        let imagesString = try ImageEnumBuilder.imageEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "I")
        let colorsString = try ColorEnumBuilder.colorEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "C")
        let localizationsString = try LocalizationEnumBuilder.localizationsEnumString(forFilesAtPaths: resourcePaths.localizationPaths, topLevelName: "L")
        
        let declarations = [imagesString, colorsString, localizationsString].compactMap({ $0?.indented(withLevel: 1) }).joined(separator: "\n\n")
        
        return """
        public enum \(parseResult.topLevelEnumName) {
        \(declarations)
        }
        """
    }
}
