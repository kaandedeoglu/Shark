import Foundation

/// Translates gaps batch-wise via the Claude API and machine-checks every
/// returned value before it is accepted.
public struct Translator {
    public struct Outcome {
        public internal(set) var translated: [(gap: TranslationGap, value: String)] = []
        public internal(set) var failed: [(gap: TranslationGap, reason: String)] = []
        public internal(set) var usage = ClaudeClient.Usage(inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
    }

    static let roleInstructions = """
    You are a professional localizer for Apple-platform apps. Translate user-facing strings from the source locale into the requested target locale.

    Rules:
    - Preserve printf-style format specifiers exactly. Every specifier in the source must appear in the translation. Reordering with positional specifiers (%1$@, %2$@, …) is allowed and encouraged when the target grammar requires it.
    - Localization keys often encode UI placement (…_BUTTON, …_TITLE, …_LABEL). Use them as context: button titles and headings must stay short.
    - Match the tone and approximate length of the source. Use the target locale's typographic conventions for quotation marks and ellipses instead of ASCII approximations.
    - Translate only the given strings and return every requested key exactly once.
    """

    static let responseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "translations": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "key": ["type": "string"],
                        "value": ["type": "string"],
                    ],
                    "required": ["key", "value"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["translations"],
        "additionalProperties": false,
    ]

    private let client: ClaudeClient
    private let appContext: String?
    private let glossary: String?
    private let batchSize: Int
    private let progress: (String) -> Void

    public init(client: ClaudeClient, appContext: String? = nil, glossary: String? = nil, batchSize: Int = 30, progress: @escaping (String) -> Void = { _ in }) {
        self.client = client
        self.appContext = appContext
        self.glossary = glossary
        self.batchSize = max(1, batchSize)
        self.progress = progress
    }

    public func translate(gaps: [TranslationGap]) async throws -> Outcome {
        var outcome = Outcome()

        // Batches never mix tables or locales, so keys stay unambiguous in
        // the response and the prompt stays coherent
        let groups = Dictionary(grouping: gaps) { "\($0.tableName)\u{1F}\($0.targetLocale)" }
        for groupKey in groups.keys.sorted() {
            let groupGaps = groups[groupKey]!
            let batches = groupGaps.chunked(into: batchSize)
            for (index, batch) in batches.enumerated() {
                progress("Translating \(batch.count) key(s) into \(batch[0].targetLocale) [\(batch[0].tableName), batch \(index + 1)/\(batches.count)]…")
                try await translate(batch: batch, into: &outcome)
            }
        }
        return outcome
    }

    private func translate(batch: [TranslationGap], into outcome: inout Outcome) async throws {
        let received = try await requestTranslations(for: batch, rejectionNotes: [:], outcome: &outcome)

        var rejected: [TranslationGap] = []
        var rejectionNotes: [String: String] = [:]
        for gap in batch {
            if let reason = Self.validate(value: received[gap.key], for: gap) {
                rejected.append(gap)
                rejectionNotes[gap.key] = reason
            } else {
                outcome.translated.append((gap, received[gap.key]!))
            }
        }
        guard rejected.isEmpty == false else { return }

        // One retry for the rejected keys, telling the model what was wrong
        progress("Retrying \(rejected.count) rejected key(s)…")
        let retried = try await requestTranslations(for: rejected, rejectionNotes: rejectionNotes, outcome: &outcome)
        for gap in rejected {
            if let reason = Self.validate(value: retried[gap.key], for: gap) {
                outcome.failed.append((gap, reason))
            } else {
                outcome.translated.append((gap, retried[gap.key]!))
            }
        }
    }

    private func requestTranslations(for batch: [TranslationGap], rejectionNotes: [String: String], outcome: inout Outcome) async throws -> [String: String] {
        let completion = try await client.complete(system: systemBlocks(),
                                                   userMessage: Self.userMessage(for: batch, rejectionNotes: rejectionNotes),
                                                   jsonSchema: Self.responseSchema)
        outcome.usage = outcome.usage.adding(completion.usage)

        struct Response: Decodable {
            struct Translation: Decodable {
                let key: String
                let value: String
            }
            let translations: [Translation]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: completion.text.data(using: .utf8) ?? Data())
        return Dictionary(decoded.translations.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    func systemBlocks() -> [ClaudeClient.SystemBlock] {
        var sections: [String] = []
        if let appContext, appContext.isEmpty == false {
            sections.append("App context:\n\(appContext)")
        }
        if let glossary, glossary.isEmpty == false {
            sections.append("Glossary — use these translations for the listed terms:\n\(glossary)")
        }
        // cache_control marks the end of the stable prefix; the volatile batch
        // payload lives in the user message, after the breakpoint
        guard sections.isEmpty == false else {
            return [ClaudeClient.SystemBlock(text: Self.roleInstructions, cached: true)]
        }
        return [ClaudeClient.SystemBlock(text: Self.roleInstructions),
                ClaudeClient.SystemBlock(text: sections.joined(separator: "\n\n"), cached: true)]
    }

    static func userMessage(for batch: [TranslationGap], rejectionNotes: [String: String]) -> String {
        struct Item: Encodable {
            let key: String
            let source: String
            let note: String?
        }
        let items = batch.sorted { $0.key < $1.key }.map { gap in
            Item(key: gap.key,
                 source: gap.sourceValue,
                 note: rejectionNotes[gap.key].map { "A previous attempt was rejected: \($0)" })
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = String(data: (try? encoder.encode(items)) ?? Data(), encoding: .utf8) ?? "[]"
        return """
        Source locale: \(batch[0].sourceLocale)
        Target locale: \(batch[0].targetLocale)

        Translate these strings:
        \(payload)
        """
    }

    /// Machine-checked acceptance — the part a generic translation tool can't
    /// do. Returns a rejection reason, or nil if the value is acceptable.
    static func validate(value: String?, for gap: TranslationGap) -> String? {
        guard let value, value.isEmpty == false else {
            return "no value returned for this key"
        }
        if let mismatch = LocalizationLinter.placeholderMismatch(source: gap.sourceValue, translation: value) {
            return mismatch
        }
        return nil
    }
}

extension ClaudeClient.Usage {
    func adding(_ other: ClaudeClient.Usage?) -> ClaudeClient.Usage {
        ClaudeClient.Usage(inputTokens: (inputTokens ?? 0) + (other?.inputTokens ?? 0),
                           outputTokens: (outputTokens ?? 0) + (other?.outputTokens ?? 0),
                           cacheCreationInputTokens: (cacheCreationInputTokens ?? 0) + (other?.cacheCreationInputTokens ?? 0),
                           cacheReadInputTokens: (cacheReadInputTokens ?? 0) + (other?.cacheReadInputTokens ?? 0))
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
