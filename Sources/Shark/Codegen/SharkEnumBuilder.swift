import Foundation
enum SharkEnumBuilder {
    private static let bundleString = """
        private let bundle: Bundle = {
            class Custom {}
            return Bundle(for: Custom.self)
        }()
        """

    private static let localizedStringKeyString = """
        extension String {
            public var localizedStringKey: LocalizedStringKey { .init(self) }
        }
        """

    static func sharkEnumString(forOptions options: Options) async throws -> String {
        let resourcePaths = try await XcodeProjectHelper(options: options).resourcePaths()
        
        let imagesString = try NestedEnumBuilder<ImageAsset>.enumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "I", options: options)
        let colorsString = try NestedEnumBuilder<ColorAsset>.enumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "C", options: options)
        let localizationsString = try LocalizationEnumBuilder.localizationsEnumString(forFilesAtPaths: resourcePaths.localizationPaths, topLevelName: "L", options: options)
        let fontsString = try FontEnumBuilder.fontsEnumString(forFilesAtPaths: resourcePaths.fontPaths, topLevelName: "F", options: options)
        let dataAssetsString = try NestedEnumBuilder<DataAsset>.enumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "D", options: options)
        let storyboardString = try StoryboardBuilder.storyboardEnumString(forFilesAtPaths: resourcePaths.storyboardPaths, topLevelName: "S", options: options)
        let declarationIndendationLevel = options.topLevelScope ? 0 : 1
        let resourcesEnumsString = [imagesString, colorsString, fontsString, localizationsString, storyboardString, dataAssetsString]
            .compactMap({ $0?.indented(withLevel: declarationIndendationLevel) })
            .joined(separator: "\n\n")

        var result = """
        \(bundleString)


        """
        if options.framework == .swiftui {
            result += """
        \(localizedStringKeyString)


        """
        }

        if options.topLevelScope {
            result.append(resourcesEnumsString)
        } else {
            result.append("\(options.visibility) enum \(options.topLevelEnumName) {\n")
            result.append(resourcesEnumsString)
            result.append("\n}")
        }
        return result
    }
}
