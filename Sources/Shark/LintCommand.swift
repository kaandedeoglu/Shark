import Foundation
import ArgumentParser
import SharkKit

struct Lint: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(commandName: "lint",
                                                           abstract: "Check localizations for missing keys, orphaned keys, and placeholder mismatches",
                                                           discussion: "Exits with code 1 when issues are found, making it suitable as a CI gate.")

    @Argument(help: "The .xcodeproj file path", transform: Options.validatedProjectPath)
    private var projectPath: String

    @Option(name: .customLong("target"),
            help: "Target name of the application, useful in case there are multiple application targets")
    private var targetName: String?

    @Option(name: .long,
            help: "Source locale the translations are checked against. Only used for .strings tables — .xcstrings catalogs declare their own.")
    private var sourceLocale: String = "en"

    @Option(name: .long,
            help: "Output format. Valid formats are 'text', 'json', and 'github' (workflow annotations).")
    private var format: LintReportFormat = .text

    @Option(name: .customLong("exclude"),
            help: "Exclude a file from processing (postfix matching).")
    private var exclude: [String] = []

    @Flag(help: "Also fail on orphaned keys (keys missing from the source locale)")
    private var strict: Bool = false

    func run() async throws {
        let tables = try await LocalizationProject.tables(projectPath: projectPath,
                                                          targetName: targetName,
                                                          sourceLocale: sourceLocale,
                                                          excludes: exclude)
        let findings = LocalizationLinter.lint(tables: tables)

        var skippedPluralKeys: [String: Set<String>] = [:]
        for table in tables {
            skippedPluralKeys[table.name, default: []].formUnion(table.skippedPluralKeys)
        }

        print(LintReportFormatter.report(findings: findings, skippedPluralKeys: skippedPluralKeys, format: format))

        let fails = findings.contains { $0.rule.failsByDefault || (strict && $0.rule == .orphanedKey) }
        if fails {
            throw ExitCode(1)
        }
    }
}
