import Foundation

/// Backend that pipes prompts through a locally installed Codex CLI binary
/// (`codex exec --output-schema ...`). It lets developers use their Codex
/// subscription without introducing another direct API client.
public struct CodexBackend: CompletionProviding {
    public enum BackendError: LocalizedError {
        case processFailed(status: Int32, stderr: String)
        case missingOutput
        case unexpectedOutput(String)

        public var errorDescription: String? {
            switch self {
                case .processFailed(let status, let stderr):
                    return "codex exited with status \(status): \(stderr)"
                case .missingOutput:
                    return "codex did not write a final response"
                case .unexpectedOutput(let output):
                    return "codex returned unexpected output: \(output.prefix(200))"
            }
        }
    }

    private let binaryPath: String
    private let model: String?

    public init(binaryPath: String, model: String? = nil) {
        self.binaryPath = binaryPath
        self.model = model
    }

    /// Looks for the binary in PATH. The lowercase name is the normal CLI;
    /// the capitalized fallback keeps older/manual macOS installs usable.
    public static func findBinary() -> String? {
        findBinary(named: "codex") ?? findBinary(named: "Codex")
    }

    static func findBinary(named name: String) -> String? {
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
        let runDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("shark-codex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: runDirectory) }

        let schemaURL = runDirectory.appendingPathComponent("response-schema.json")
        let outputURL = runDirectory.appendingPathComponent("last-message.json")
        let schemaData = try JSONSerialization.data(withJSONObject: jsonSchema, options: [.prettyPrinted, .sortedKeys])
        try schemaData.write(to: schemaURL)

        let arguments = Self.arguments(model: model,
                                       schemaPath: schemaURL.path,
                                       outputPath: outputURL.path,
                                       workingDirectory: runDirectory.path)
        let prompt = Self.prompt(system: system, userMessage: userMessage)
        let stdout = try Self.run(binaryPath: binaryPath, arguments: arguments, stdin: prompt)
        let output = (try? Data(contentsOf: outputURL)).flatMap { $0.isEmpty ? nil : $0 } ?? stdout

        guard output.isEmpty == false else {
            throw BackendError.missingOutput
        }
        return ClaudeClient.Completion(text: try Self.parse(output), usage: nil)
    }

    static func arguments(model: String?, schemaPath: String, outputPath: String, workingDirectory: String) -> [String] {
        var arguments = [
            "exec",
            "--cd", workingDirectory,
            "--skip-git-repo-check",
            "--ephemeral",
            "--ignore-rules",
            "--sandbox", "read-only",
            "--ask-for-approval", "never",
            "--color", "never",
            "--output-schema", schemaPath,
            "--output-last-message", outputPath,
        ]
        if let model, model.isEmpty == false {
            arguments += ["--model", model]
        }
        arguments.append("-")
        return arguments
    }

    static func prompt(system: [ClaudeClient.SystemBlock], userMessage: String) -> String {
        var sections = system.map(\.text)
        sections.append(userMessage)
        sections.append("Return only the JSON object requested by the output schema. Do not include markdown fences or commentary.")
        return sections.joined(separator: "\n\n")
    }

    static func parse(_ data: Data) throws -> String {
        let raw = String(data: data, encoding: .utf8) ?? "<binary>"
        let text = ClaudeCodeBackend.strippingCodeFence(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let jsonData = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
            throw BackendError.unexpectedOutput(raw)
        }
        return text
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
