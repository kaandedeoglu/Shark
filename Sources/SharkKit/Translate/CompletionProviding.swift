import Foundation

/// What the Translator actually needs from a model backend — one completion
/// call. Implemented by ClaudeClient (direct API), ClaudeCodeBackend, and
/// CodexBackend (piping through locally installed agent binaries).
public protocol CompletionProviding: Sendable {
    func complete(system: [ClaudeClient.SystemBlock], userMessage: String, jsonSchema: [String: Any]) async throws -> ClaudeClient.Completion
}

extension ClaudeClient: CompletionProviding {}
