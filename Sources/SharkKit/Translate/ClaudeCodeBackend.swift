import Foundation

/// Backend that pipes prompts through a locally installed Claude Code binary
/// (`claude -p --output-format json --json-schema ...`). Useful for individual
/// developers: it bills against the existing Claude subscription and needs no
/// API key. The direct API backend remains the better fit for CI — prompt
/// caching, retries, and no dependency on an installed binary.
public struct ClaudeCodeBackend: CompletionProviding {
    public enum BackendError: LocalizedError {
        case processFailed(status: Int32, stderr: String)
        case unexpectedOutput(String)

        public var errorDescription: String? {
            switch self {
                case .processFailed(let status, let stderr):
                    return "claude exited with status \(status): \(stderr)"
                case .unexpectedOutput(let output):
                    return "claude returned unexpected output: \(output.prefix(200))"
            }
        }
    }

    private let binaryPath: String
    private let model: String?

    public init(binaryPath: String, model: String? = nil) {
        self.binaryPath = binaryPath
        self.model = model
    }

    /// Looks for the binary in PATH
    public static func findBinary(named name: String = "claude") -> String? {
        let searchPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in searchPath.split(separator: ":") {
            let candidate = "\(directory)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    public func complete(system: [ClaudeClient.SystemBlock], userMessage: String, jsonSchema: [String: Any]) async throws -> ClaudeClient.Completion {
        let arguments = try Self.arguments(model: model, jsonSchema: jsonSchema)
        let prompt = Self.prompt(system: system, userMessage: userMessage, jsonSchema: jsonSchema)
        let output = try Self.run(binaryPath: binaryPath, arguments: arguments, stdin: prompt)
        return try Self.parse(output)
    }

    static func arguments(model: String?, jsonSchema: [String: Any]) throws -> [String] {
        let schemaData = try JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])
        guard let schema = String(data: schemaData, encoding: .utf8) else {
            throw BackendError.unexpectedOutput("Could not encode JSON schema")
        }

        var arguments = ["-p", "--output-format", "json", "--json-schema", schema]
        if let model {
            arguments += ["--model", model]
        }
        return arguments
    }

    /// The schema is enforced by Claude Code and mirrored in the prompt. The
    /// Translator's validation layer still catches semantic strays.
    static func prompt(system: [ClaudeClient.SystemBlock], userMessage: String, jsonSchema: [String: Any]) -> String {
        var sections = system.map(\.text)
        sections.append(userMessage)
        if let schemaData = try? JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys]),
           let schema = String(data: schemaData, encoding: .utf8) {
            sections.append("Respond with ONLY a JSON object matching this JSON schema — no markdown fences, no commentary:\n\(schema)")
        } else {
            sections.append("Respond with ONLY the JSON object — no markdown fences, no commentary.")
        }
        return sections.joined(separator: "\n\n")
    }

    static func parse(_ data: Data) throws -> ClaudeClient.Completion {
        struct Envelope: Decodable {
            let result: String?
            let isError: Bool?
            let usage: ClaudeClient.Usage?

            enum CodingKeys: String, CodingKey {
                case result
                case isError = "is_error"
                case usage
            }
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let result = envelope.result,
              envelope.isError != true else {
            throw BackendError.unexpectedOutput(String(data: data, encoding: .utf8) ?? "<binary>")
        }
        return ClaudeClient.Completion(text: strippingCodeFence(result.trimmingCharacters(in: .whitespacesAndNewlines)),
                                       usage: envelope.usage)
    }

    static func strippingCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```") else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private static func run(binaryPath: String, arguments: [String], stdin prompt: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(prompt.data(using: .utf8) ?? Data())
        stdinPipe.fileHandleForWriting.closeFile()

        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw BackendError.processFailed(status: process.terminationStatus,
                                             stderr: String(data: errorOutput, encoding: .utf8) ?? "")
        }
        return output
    }
}
