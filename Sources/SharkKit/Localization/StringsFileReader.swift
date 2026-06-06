import Foundation

/// Groups `.strings` files by table name and reads them into
/// `LocalizationTable`s spanning all locales found on disk.
public enum StringsFileReader {
    public static func tables(forPaths paths: [String], sourceLocale: String) throws -> [LocalizationTable] {
        var pathsByTable: [String: [String: String]] = [:]
        for path in paths {
            let tableName = path.lastPathComponent.replacingOccurrences(of: ".strings", with: "")
            let locale = StringsFileReader.locale(forPath: path) ?? sourceLocale
            pathsByTable[tableName, default: [:]][locale] = path
        }

        return try pathsByTable.keys.sorted().map { tableName in
            let pathsByLocale = pathsByTable[tableName]!
            var terms: [String: [String: LocalizationTerm]] = [:]
            for (locale, path) in pathsByLocale {
                guard let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] else {
                    throw LocalizationFileError.invalidStringsFile(path: path)
                }
                for (key, value) in dictionary {
                    terms[key, default: [:]][locale] = LocalizationTerm(value: value, state: nil)
                }
            }
            return LocalizationTable(name: tableName,
                                     sourceLocale: sourceLocale,
                                     origin: .stringsFiles(pathsByLocale: pathsByLocale),
                                     locales: Set(pathsByLocale.keys),
                                     terms: terms,
                                     skippedPluralKeys: [])
        }
    }

    /// Extracts the locale from the enclosing `<locale>.lproj` folder
    static func locale(forPath path: String) -> String? {
        let components = path.pathComponents
        guard components.count >= 2 else { return nil }
        let parent = components[components.count - 2]
        guard parent.hasSuffix(".lproj") else { return nil }
        return parent.replacingOccurrences(of: ".lproj", with: "")
    }
}
