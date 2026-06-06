import Foundation
import ArgumentParser
import SharkKit

struct Translate: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(commandName: "translate",
                                                           abstract: "Translate missing localization keys via the Claude API",
                                                           discussion: """
                                                           Finds keys that exist in the source locale but are missing in the target locale(s) \
                                                           and translates them with Claude. Format specifiers are machine-validated and results \
                                                           are written as 'needs_review', so Xcode's String Catalog editor keeps the human in \
                                                           the loop. Requires the ANTHROPIC_API_KEY environment variable.
                                                           """)

    @Argument(help: "The .xcodeproj file path", transform: Options.validatedProjectPath)
    private var projectPath: String

    @Option(name: .customLong("to"),
            help: "Comma-separated target locales, e.g. 'de,fr'",
            transform: { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } })
    private var targetLocales: [String]

    @Option(name: .customLong("target"),
            help: "Target name of the application, useful in case there are multiple application targets")
    private var targetName: String?

    @Option(name: .long,
            help: "Source locale to translate from. Only used for .strings tables — .xcstrings catalogs declare their own.")
    private var sourceLocale: String = "en"

    @Option(name: .customLong("exclude"),
            help: "Exclude a file from processing (postfix matching).")
    private var exclude: [String] = []

    @Option(name: .long,
            help: "Path to a Markdown glossary handed to the model (project-specific terminology)")
    private var glossary: String?

    @Option(name: .long,
            help: "Path to a Markdown file describing the app, handed to the model as context")
    private var context: String?

    @Option(name: .long,
            help: "Claude model to use. 'claude-sonnet-4-6' or 'claude-haiku-4-5' trade quality for cost.")
    private var model: String = "claude-opus-4-8"

    @Option(name: .long,
            help: "Keys per API request")
    private var batchSize: Int = 30

    @Flag(name: .long,
          help: "List what would be translated without calling the API")
    private var dryRun: Bool = false

    @Flag(name: .customLong("yes"),
          help: "Skip the confirmation prompt")
    private var skipConfirmation: Bool = false

    func run() async throws {
        let tables = try await LocalizationProject.tables(projectPath: projectPath,
                                                          targetName: targetName,
                                                          sourceLocale: sourceLocale,
                                                          excludes: exclude)
        let allGaps = TranslationGapAnalyzer.gaps(tables: tables, targetLocales: targetLocales)
        let unsupported = TranslationGapAnalyzer.unsupportedGaps(in: allGaps)
        let gaps = allGaps.filter { gap in unsupported.contains(gap) == false }

        for gap in Set(unsupported.map { "\($0.targetLocale).lproj/\($0.tableName).strings" }).sorted() {
            print("warning: skipping keys for missing file \(gap) — create it in Xcode first")
        }

        guard gaps.isEmpty == false else {
            print("Nothing to translate — all keys are localized for \(targetLocales.joined(separator: ", ")).")
            return
        }

        var countsByLocale: [String: Int] = [:]
        for gap in gaps {
            countsByLocale[gap.targetLocale, default: 0] += 1
        }
        let summary = countsByLocale.sorted { $0.key < $1.key }.map { "\($0.value) → \($0.key)" }.joined(separator: ", ")
        print("Missing translations: \(summary) (model: \(model))")

        if dryRun {
            for gap in gaps {
                print("  [\(gap.tableName)] \(gap.key) → \(gap.targetLocale)")
            }
            return
        }

        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], apiKey.isEmpty == false else {
            throw ValidationError("ANTHROPIC_API_KEY is not set. Export your Anthropic API key to use shark translate.")
        }

        let glossaryText = try glossary.map { try String(contentsOfFile: $0, encoding: .utf8) }
        let contextText = try context.map { try String(contentsOfFile: $0, encoding: .utf8) }

        if skipConfirmation == false {
            let batchCount = (gaps.count + batchSize - 1) / batchSize
            print("This sends \(gaps.count) key(s) in ~\(batchCount) request(s) to \(model). Continue? [y/N] ", terminator: "")
            guard let answer = readLine(), ["y", "yes"].contains(answer.lowercased()) else {
                print("Aborted.")
                return
            }
        }

        let client = ClaudeClient(configuration: .init(apiKey: apiKey, model: model))
        let translator = Translator(client: client,
                                    appContext: contextText,
                                    glossary: glossaryText,
                                    batchSize: batchSize,
                                    progress: { print($0) })

        let outcome = try await translator.translate(gaps: gaps)
        let writeBack = try TranslationWriteBack.write(outcome.translated)

        for (locale, count) in writeBack.writtenByLocale.sorted(by: { $0.key < $1.key }) {
            print("\(locale): \(count) translation(s) written as needs_review")
        }
        let failures = outcome.failed + writeBack.failed
        for failure in failures {
            print("failed: [\(failure.gap.tableName)] \(failure.gap.key) → \(failure.gap.targetLocale): \(failure.reason)")
        }
        if let input = outcome.usage.inputTokens, let output = outcome.usage.outputTokens {
            let cached = outcome.usage.cacheReadInputTokens ?? 0
            print("Tokens: \(input) in (\(cached) cached), \(output) out")
        }
        print("Review the new translations in Xcode's String Catalog editor (filter: NEEDS REVIEW).")

        if failures.isEmpty == false {
            throw ExitCode(1)
        }
    }
}
