import Foundation
enum SharkEnumBuilder {
    private static let bundleString = """
        private let bundle: Bundle = {
            class Custom {}
            return Bundle(for: Custom.self)
        }()
        """

    static func sharkEnumString(forOptions options: Options) throws -> String {
        let resourcePaths = try XcodeProjectHelper(options: options).resourcePaths()
        
        let imagesString = try ImageEnumBuilder.imageEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "I", options: options)
        let colorsString = try ColorEnumBuilder.colorEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "C", options: options)
        let localizationsString = try LocalizationEnumBuilder.localizationsEnumString(forFilesAtPaths: resourcePaths.localizationPaths, topLevelName: "L", options: options)
        let fontsString = try FontEnumBuilder.fontsEnumString(forFilesAtPaths: resourcePaths.fontPaths, topLevelName: "F", options: options)
        let dataAssetsString = try DataAssetEnumBuilder.dataAssetEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "D")
        let storyboardString = try StoryboardBuilder.storyboardEnumString(forFilesAtPaths: resourcePaths.storyboardPaths, topLevelName: "S", options: options)
        let declarationIndendationLevel = options.topLevelScope ? 0 : 1
        let resourcesEnumsString = [imagesString, colorsString, fontsString, localizationsString, storyboardString, dataAssetsString]
            .compactMap({ $0?.indented(withLevel: declarationIndendationLevel) })
            .joined(separator: "\n\n")

        var result = """
        \(bundleString)


        """

        if options.topLevelScope {
            result.append(resourcesEnumsString)
        } else {
            result.append("public enum \(options.topLevelEnumName) {\n")
            result.append(resourcesEnumsString)
            result.append("\n}")
        }
        return result
    }
}
