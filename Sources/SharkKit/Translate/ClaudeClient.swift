import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Minimal client for the Anthropic Messages API. There is no official Swift
/// SDK, and Shark's needs are narrow — one endpoint, structured output — so a
/// thin URLSession wrapper beats a third-party dependency.
public struct ClaudeClient: Sendable {
    public struct Configuration: Sendable {
        public let apiKey: String
        public let model: String
        public let maxTokens: Int
        public let baseURL: URL
        public let maxRetries: Int
        public let retryBaseDelay: TimeInterval

        public init(apiKey: String,
                    model: String = "claude-opus-4-8",
                    maxTokens: Int = 16000,
                    baseURL: URL = URL(string: "https://api.anthropic.com")!,
                    maxRetries: Int = 3,
                    retryBaseDelay: TimeInterval = 2) {
            self.apiKey = apiKey
            self.model = model
            self.maxTokens = maxTokens
            self.baseURL = baseURL
            self.maxRetries = maxRetries
            self.retryBaseDelay = retryBaseDelay
        }
    }

    public struct SystemBlock: Sendable {
        public let text: String
        /// Marks the end of the stable prompt prefix — the API caches up to
        /// this block, so repeated batch requests reuse the expensive part
        public let cached: Bool

        public init(text: String, cached: Bool = false) {
            self.text = text
            self.cached = cached
        }
    }

    public struct Usage: Decodable, Equatable, Sendable {
        public let inputTokens: Int?
        public let outputTokens: Int?
        public let cacheCreationInputTokens: Int?
        public let cacheReadInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }

        public init(inputTokens: Int?, outputTokens: Int?, cacheCreationInputTokens: Int?, cacheReadInputTokens: Int?) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cacheCreationInputTokens = cacheCreationInputTokens
            self.cacheReadInputTokens = cacheReadInputTokens
        }
    }

    public struct Completion: Sendable {
        public let text: String
        public let usage: Usage?
    }

    public enum ClientError: LocalizedError {
        case httpError(status: Int, message: String, retryAfterSeconds: Int?)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
                case .httpError(let status, let message, _):
                    return "Claude API request failed (HTTP \(status)): \(message)"
                case .invalidResponse:
                    return "Claude API returned an unexpected response"
            }
        }

        var isRetryable: Bool {
            switch self {
                case .httpError(let status, _, _):
                    return status == 429 || status >= 500
                case .invalidResponse:
                    return false
            }
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func complete(system: [SystemBlock], userMessage: String, jsonSchema: [String: Any]) async throws -> Completion {
        var attempt = 0
        while true {
            do {
                return try await performRequest(system: system, userMessage: userMessage, jsonSchema: jsonSchema)
            } catch let error as ClientError where error.isRetryable && attempt < configuration.maxRetries {
                attempt += 1
                let delay: TimeInterval
                if case .httpError(_, _, let retryAfterSeconds) = error, let retryAfterSeconds {
                    delay = TimeInterval(retryAfterSeconds)
                } else {
                    delay = configuration.retryBaseDelay * pow(2, Double(attempt - 1))
                }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func performRequest(system: [SystemBlock], userMessage: String, jsonSchema: [String: Any]) async throws -> Completion {
        var body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": configuration.maxTokens,
            "thinking": ["type": "adaptive"],
            "messages": [["role": "user", "content": userMessage]],
            "output_config": ["format": ["type": "json_schema", "schema": jsonSchema]],
        ]
        if system.isEmpty == false {
            body["system"] = system.map { block -> [String: Any] in
                var blockDictionary: [String: Any] = ["type": "text", "text": block.text]
                if block.cached {
                    blockDictionary["cache_control"] = ["type": "ephemeral"]
                }
                return blockDictionary
            }
        }

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("v1/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after").flatMap(Int.init)
            throw ClientError.httpError(status: httpResponse.statusCode,
                                        message: Self.errorMessage(from: data),
                                        retryAfterSeconds: retryAfter)
        }

        struct Response: Decodable {
            struct Block: Decodable {
                let type: String
                let text: String?
            }
            let content: [Block]
            let usage: Usage?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ClientError.invalidResponse
        }
        return Completion(text: text, usage: decoded.usage)
    }

    private static func errorMessage(from data: Data) -> String {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable {
                let message: String
            }
            let error: APIError
        }
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return envelope.error.message
        }
        return String(data: data, encoding: .utf8) ?? "<no body>"
    }
}
