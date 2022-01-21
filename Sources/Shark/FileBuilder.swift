enum FileBuilder {
    static func fileContents(with enumString: String, options: Options) -> String {

        return """
        // \(options.outputPath.lastPathComponent)
        // Generated by Shark https://github.com/kaandedeoglu/Shark
        
        \(options.framework.importStatement)

        // swiftlint:disable all
        // swiftformat:disable all
        \(enumString)

        """
    }
}
