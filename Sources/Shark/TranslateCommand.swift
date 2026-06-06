import Foundation
import ArgumentParser
import SharkKit

struct Translate: AsyncParsableCommand {
    private static let defaultClaudeModel = "claude-opus-4-8"

    static var configuration: CommandConfiguration = .init(commandName: "translate",
                                                           abstract: "Translate missing localization keys via a local agent or API backend",
                                                           discussion: """
                                                           Finds keys that exist in the source locale but are missing in the target locale(s) \
                                                           and translates them with a local agent or API backend. Format specifiers are machine-validated and results \
                                                           are written as 'needs_review', so Xcode's String Catalog editor keeps the human in \
                                                           the loop.
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
            help: "Model to use. Defaults to 'claude-opus-4-8' for Claude backends; the codex backend uses your Codex CLI default unless set.")
    private var model: String?

    enum Backend: String, ExpressibleByArgument {
        case auto
        case api
        case claudeCode = "claude-code"
        case codex
    }

    @Option(name: .long,
            help: "Model backend: 'claude-code' (default; local Claude Code install), 'api' (ANTHROPIC_API_KEY; structured output and prompt caching — best for CI), 'codex' (local Codex CLI), or 'auto' (api if a key is set, otherwise claude-code, otherwise codex).")
    private var backend: Backend = .claudeCode

    @Option(name: .long,
            help: "Keys per model request")
    private var batchSize: Int = 30

    @Flag(name: .long,
          help: "List what would be translated without calling the selected backend")
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
        let estimateModel = model ?? defaultEstimateModel()
        print("Missing translations: \(summary) (model: \(estimateModel))")

        let glossaryText = try glossary.map { try String(contentsOfFile: $0, encoding: .utf8) }
        let contextText = try context.map { try String(contentsOfFile: $0, encoding: .utf8) }
        let estimate = TranslationCostEstimator.estimate(gaps: gaps,
                                                         glossary: glossaryText,
                                                         appContext: contextText,
                                                         batchSize: batchSize,
                                                         model: estimateModel)

        if dryRun {
            for gap in gaps {
                print("  [\(gap.tableName)] \(gap.key) → \(gap.targetLocale)")
            }
            print("Estimate: \(estimate.description)")
            return
        }

        let (provider, backendDescription) = try resolvedProvider()
        print("Backend: \(backendDescription)")

        if skipConfirmation == false {
            print("This sends \(gaps.count) key(s) — \(estimate.description). Continue? [y/N] ", terminator: "")
            guard let answer = readLine(), ["y", "yes"].contains(answer.lowercased()) else {
                print("Aborted.")
                return
            }
        }

        let translator = Translator(provider: provider,
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
        let wroteCatalog = outcome.translated.contains { if case .stringCatalog = $0.gap.origin { return true } else { return false } }
        let wroteStrings = outcome.translated.contains { if case .stringsFiles = $0.gap.origin { return true } else { return false } }
        if wroteCatalog {
            print("Review the new translations in Xcode's String Catalog editor (filter: NEEDS REVIEW).")
        }
        if wroteStrings {
            print("Review the blocks appended under the \"Added by shark translate\" comment in each .lproj file.")
        }

        if failures.isEmpty == false {
            throw ExitCode(1)
        }
    }

    private func resolvedProvider() throws -> (any CompletionProviding, String) {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        let claudeModel = model ?? Self.defaultClaudeModel

        func apiProvider() throws -> (any CompletionProviding, String) {
            guard let apiKey, apiKey.isEmpty == false else {
                throw ValidationError("ANTHROPIC_API_KEY is not set. Export your Anthropic API key, or use --backend claude-code with a local Claude Code install.")
            }
            return (ClaudeClient(configuration: .init(apiKey: apiKey, model: claudeModel)), "Claude API")
        }

        func claudeCodeProvider() throws -> (any CompletionProviding, String) {
            guard let binaryPath = ClaudeCodeBackend.findBinary() else {
                throw ValidationError("No 'claude' binary found in PATH. Install Claude Code, or use --backend api with ANTHROPIC_API_KEY, or use --backend codex with a local Codex CLI install.")
            }
            return (ClaudeCodeBackend(binaryPath: binaryPath, model: claudeModel),
                    "Claude Code (\(binaryPath), billed to your Claude subscription)")
        }

        func codexProvider() throws -> (any CompletionProviding, String) {
            guard let binaryPath = CodexBackend.findBinary() else {
                throw ValidationError("No 'codex' binary found in PATH. Install Codex CLI, or use --backend claude-code with a local Claude Code install.")
            }
            let modelDescription = model.map { ", model: \($0)" } ?? ", model: Codex CLI default"
            return (CodexBackend(binaryPath: binaryPath, model: model),
                    "Codex CLI (\(binaryPath)\(modelDescription))")
        }

        switch backend {
            case .api:
                return try apiProvider()
            case .claudeCode:
                return try claudeCodeProvider()
            case .codex:
                return try codexProvider()
            case .auto:
                if let apiKey, apiKey.isEmpty == false {
                    return try apiProvider()
                }
                if ClaudeCodeBackend.findBinary() != nil {
                    return try claudeCodeProvider()
                }
                if CodexBackend.findBinary() != nil {
                    return try codexProvider()
                }
                throw ValidationError("Neither ANTHROPIC_API_KEY is set nor a 'claude' or 'codex' binary was found in PATH. Set up one of the supported backends.")
        }
    }

    private func defaultEstimateModel() -> String {
        switch backend {
            case .codex:
                return "codex-default"
            case .auto:
                let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
                if let apiKey, apiKey.isEmpty == false {
                    return Self.defaultClaudeModel
                }
                if ClaudeCodeBackend.findBinary() != nil {
                    return Self.defaultClaudeModel
                }
                if CodexBackend.findBinary() != nil {
                    return "codex-default"
                }
                return Self.defaultClaudeModel
            case .api, .claudeCode:
                return Self.defaultClaudeModel
        }
    }
}
