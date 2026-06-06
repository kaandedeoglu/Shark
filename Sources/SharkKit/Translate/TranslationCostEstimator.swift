import Foundation

/// Rough upper-bound estimate (~4 characters per token) so the confirmation
/// prompt can show what a run will send before any API call is made.
public enum TranslationCostEstimator {
    private static let pricingPerMTok: [String: (input: Double, output: Double)] = [
        "claude-opus-4-8": (5, 25),
        "claude-opus-4-7": (5, 25),
        "claude-opus-4-6": (5, 25),
        "claude-sonnet-4-6": (3, 15),
        "claude-haiku-4-5": (1, 5),
    ]

    public struct Estimate {
        public let batchCount: Int
        public let inputTokens: Int
        public let outputTokens: Int
        /// nil for models without a known price
        public let dollars: Double?

        public var description: String {
            var text = "≈ \(inputTokens) input / \(outputTokens) output tokens in \(batchCount) request(s)"
            if let dollars {
                text += String(format: ", ≈ $%.2f before cache savings", dollars)
            }
            return text
        }
    }

    public static func estimate(gaps: [TranslationGap], glossary: String?, appContext: String?, batchSize: Int, model: String) -> Estimate {
        // Mirror the Translator's grouping: batches never mix tables/locales
        let groups = Dictionary(grouping: gaps) { "\($0.tableName)\u{1F}\($0.targetLocale)" }
        let size = max(1, batchSize)
        let batchCount = groups.values.reduce(0) { $0 + ($1.count + size - 1) / size }

        let prefixCharacters = Translator.roleInstructions.count + (glossary?.count ?? 0) + (appContext?.count ?? 0)
        let payloadCharacters = gaps.reduce(0) { $0 + $1.key.count + $1.sourceValue.count + 40 }
        let inputTokens = (prefixCharacters * batchCount + payloadCharacters) / 4
        // Translations are roughly source-sized; the constant covers response framing
        let outputTokens = payloadCharacters / 4 + batchCount * 100

        let dollars = pricingPerMTok[model].map {
            Double(inputTokens) / 1_000_000 * $0.input + Double(outputTokens) / 1_000_000 * $0.output
        }
        return Estimate(batchCount: batchCount, inputTokens: inputTokens, outputTokens: outputTokens, dollars: dollars)
    }
}
