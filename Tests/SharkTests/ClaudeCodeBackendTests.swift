import Testing
import Foundation
@testable import SharkKit

struct ClaudeCodeBackendTests {
    @Test func promptEmbedsSystemBlocksUserMessageAndSchema() {
        let prompt = ClaudeCodeBackend.prompt(system: [.init(text: "role"), .init(text: "glossary", cached: true)],
                                              userMessage: "translate",
                                              jsonSchema: Translator.responseSchema)
        #expect(prompt.hasPrefix("role\n\nglossary\n\ntranslate"))
        #expect(prompt.contains("ONLY a JSON object"))
        #expect(prompt.contains("\"translations\""))
    }

    @Test func parsesResultEnvelope() throws {
        let envelope: [String: Any] = [
            "type": "result",
            "is_error": false,
            "result": #"{"translations":[{"key":"K","value":"V"}]}"#,
            "usage": ["input_tokens": 12, "output_tokens": 34],
        ]
        let completion = try ClaudeCodeBackend.parse(JSONSerialization.data(withJSONObject: envelope))
        #expect(completion.text == #"{"translations":[{"key":"K","value":"V"}]}"#)
        #expect(completion.usage?.inputTokens == 12)
        #expect(completion.usage?.outputTokens == 34)
    }

    @Test func errorEnvelopeThrows() throws {
        let envelope: [String: Any] = ["type": "result", "is_error": true, "result": "credit exhausted"]
        #expect(throws: ClaudeCodeBackend.BackendError.self) {
            _ = try ClaudeCodeBackend.parse(try JSONSerialization.data(withJSONObject: envelope))
        }
        #expect(throws: ClaudeCodeBackend.BackendError.self) {
            _ = try ClaudeCodeBackend.parse("not json at all".data(using: .utf8)!)
        }
    }

    @Test func stripsMarkdownFences() {
        #expect(ClaudeCodeBackend.strippingCodeFence("```json\n{\"a\":1}\n```") == "{\"a\":1}")
        #expect(ClaudeCodeBackend.strippingCodeFence("{\"a\":1}") == "{\"a\":1}")
    }
}

struct TranslationCostEstimatorTests {
    @Test func estimateScalesWithBatchesAndKnowsPricing() {
        let gaps = (0..<60).map { index in
            TranslationGap(tableName: "Localizable",
                           origin: .stringCatalog(path: "/tmp/L.xcstrings"),
                           key: "KEY_\(index)",
                           sourceValue: "Some source value number \(index)",
                           sourceLocale: "en",
                           targetLocale: "de")
        }
        let estimate = TranslationCostEstimator.estimate(gaps: gaps, glossary: nil, appContext: nil, batchSize: 30, model: "claude-opus-4-8")
        #expect(estimate.batchCount == 2)
        #expect(estimate.inputTokens > 0)
        #expect(estimate.dollars != nil)
        #expect(estimate.description.contains("$"))

        let unknownModel = TranslationCostEstimator.estimate(gaps: gaps, glossary: nil, appContext: nil, batchSize: 30, model: "some-future-model")
        #expect(unknownModel.dollars == nil)
        #expect(unknownModel.description.contains("$") == false)
    }
}
