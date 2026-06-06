import Foundation

/// Facade for lint/translate: discovers a target's localization files via the
/// Xcode project and loads them into multi-locale tables.
public enum LocalizationProject {
    public static func tables(projectPath: String,
                              targetName: String?,
                              sourceLocale: String,
                              excludes: [String]) async throws -> [LocalizationTable] {
        let helper = try XcodeProjectHelper(projectPath: projectPath, targetName: targetName, excludes: excludes)
        let paths = try await helper.localizationResourcePaths()
        var tables = try StringsFileReader.tables(forPaths: paths.strings, sourceLocale: sourceLocale)
        tables += try paths.xcstrings.map(StringCatalogReader.table(atPath:))
        return tables.sorted { $0.name < $1.name }
    }
}
