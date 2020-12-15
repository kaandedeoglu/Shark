enum SharkEnumBuilder {
    static func sharkEnumString(forOptions options: Options) throws -> String {
        let resourcePaths = try XcodeProjectHelper(options: options).resourcePaths()
        
        let imagesString = try ImageEnumBuilder.imageEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "I")
        let colorsString = try ColorEnumBuilder.colorEnumString(forFilesAtPaths: resourcePaths.assetsPaths, topLevelName: "C")
        let localizationsString = try LocalizationEnumBuilder.localizationsEnumString(forFilesAtPaths: resourcePaths.localizationPaths, topLevelName: "L")
        let fontsString = try FontEnumBuilder.fontsEnumString(forFilesAtPaths: resourcePaths.fontPaths, topLevelName: "F")

        let declarations = [imagesString, colorsString, localizationsString, fontsString]
            .compactMap({ $0?.indented(withLevel: 1) })
            .joined(separator: "\n\n")
        
        return """
        public enum \(options.topLevelEnumName) {
            private static let bundle: Bundle = {
                class Custom {}
                return Bundle(for: Custom.self)
            }()

        \(declarations)
        }
        """
    }
}
