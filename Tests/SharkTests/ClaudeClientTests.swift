import Testing
import Foundation
@testable import SharkKit

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

extension URLRequest {
    /// URLSession turns httpBody into a stream before URLProtocol sees it
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

enum TestAPI {
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func client(model: String = "claude-opus-4-8", maxRetries: Int = 0) -> ClaudeClient {
        ClaudeClient(configuration: .init(apiKey: "test-key", model: model, maxRetries: maxRetries, retryBaseDelay: 0),
                     session: session())
    }

    static func response(status: Int = 200, headers: [String: String] = [:], body: Data) -> (URLRequest) -> (HTTPURLResponse, Data) {
        { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (response, body)
        }
    }

    static func completionBody(text: String, inputTokens: Int = 100, outputTokens: Int = 50, cacheRead: Int = 0) -> Data {
        let body: [String: Any] = [
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": text]],
            "usage": ["input_tokens": inputTokens, "output_tokens": outputTokens,
                      "cache_read_input_tokens": cacheRead, "cache_creation_input_tokens": 0],
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    static func translationsBody(_ translations: [(key: String, value: String)]) -> Data {
        let payload = ["translations": translations.map { ["key": $0.key, "value": $0.value] }]
        let text = String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
        return completionBody(text: text)
    }

    static func gap(key: String, source: String, locale: String = "de") -> TranslationGap {
        TranslationGap(tableName: "Localizable",
                       origin: .stringCatalog(path: "/tmp/Localizable.xcstrings"),
                       key: key,
                       sourceValue: source,
                       sourceLocale: "en",
                       targetLocale: locale)
    }
}

/// All tests sharing MockURLProtocol's static handler live in this single
/// serialized suite — separate suites would run in parallel and race on it.
@Suite(.serialized) struct APIMockedTests {
    @Test func requestCarriesHeadersPromptCachingAndSchema() async throws {
        nonisolated(unsafe) var capturedRequest: URLRequest?
        nonisolated(unsafe) var capturedBody: [String: Any]?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = try JSONSerialization.jsonObject(with: request.bodyData ?? Data()) as? [String: Any]
            return TestAPI.response(body: TestAPI.completionBody(text: "ok"))(request)
        }

        let completion = try await TestAPI.client().complete(
            system: [.init(text: "role"), .init(text: "glossary", cached: true)],
            userMessage: "translate this",
            jsonSchema: Translator.responseSchema)

        #expect(completion.text == "ok")
        #expect(completion.usage?.inputTokens == 100)

        let request = try #require(capturedRequest)
        #expect(request.url?.path == "/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")

        let body = try #require(capturedBody)
        #expect(body["model"] as? String == "claude-opus-4-8")
        #expect((body["thinking"] as? [String: Any])?["type"] as? String == "adaptive")

        let system = try #require(body["system"] as? [[String: Any]])
        try #require(system.count == 2)
        #expect(system[0]["cache_control"] == nil)
        #expect((system[1]["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral")

        let format = ((body["output_config"] as? [String: Any])?["format"] as? [String: Any])
        #expect(format?["type"] as? String == "json_schema")
        #expect(format?["schema"] != nil)
    }

    @Test func httpErrorsCarryStatusAndRetryAfter() async throws {
        let errorBody = try JSONSerialization.data(withJSONObject: ["error": ["message": "rate limited"]])
        MockURLProtocol.handler = TestAPI.response(status: 429, headers: ["retry-after": "7"], body: errorBody)

        await #expect {
            _ = try await TestAPI.client().complete(system: [], userMessage: "x", jsonSchema: [:])
        } throws: { error in
            guard case ClaudeClient.ClientError.httpError(let status, let message, let retryAfter) = error else { return false }
            return status == 429 && message == "rate limited" && retryAfter == 7
        }
    }

    @Test func retryableErrorsAreRetried() async throws {
        nonisolated(unsafe) var requestCount = 0
        let errorBody = try JSONSerialization.data(withJSONObject: ["error": ["message": "overloaded"]])
        MockURLProtocol.handler = { request in
            requestCount += 1
            if requestCount < 3 {
                return TestAPI.response(status: 529, body: errorBody)(request)
            }
            return TestAPI.response(body: TestAPI.completionBody(text: "ok"))(request)
        }

        let completion = try await TestAPI.client(maxRetries: 3).complete(system: [], userMessage: "x", jsonSchema: [:])
        #expect(completion.text == "ok")
        #expect(requestCount == 3)
    }

    @Test func nonRetryableErrorsAreNotRetried() async throws {
        nonisolated(unsafe) var requestCount = 0
        let errorBody = try JSONSerialization.data(withJSONObject: ["error": ["message": "bad request"]])
        MockURLProtocol.handler = { request in
            requestCount += 1
            return TestAPI.response(status: 400, body: errorBody)(request)
        }

        await #expect(throws: ClaudeClient.ClientError.self) {
            _ = try await TestAPI.client(maxRetries: 3).complete(system: [], userMessage: "x", jsonSchema: [:])
        }
        #expect(requestCount == 1)
    }

    @Test func translatorAcceptsValidTranslations() async throws {
        MockURLProtocol.handler = { request in
            TestAPI.response(body: TestAPI.translationsBody([
                ("GREETING", "Hallo %@"),
                ("BYE", "Tschüss"),
            ]))(request)
        }

        let translator = Translator(provider: TestAPI.client())
        let outcome = try await translator.translate(gaps: [TestAPI.gap(key: "GREETING", source: "Hello %@"),
                                                            TestAPI.gap(key: "BYE", source: "Goodbye")])

        #expect(outcome.translated.count == 2)
        #expect(outcome.failed.isEmpty)
        #expect(outcome.translated.first(where: { $0.gap.key == "GREETING" })?.value == "Hallo %@")
        #expect(outcome.usage.inputTokens == 100)
    }

    @Test func translatorRejectsDroppedPlaceholderAndRetriesWithNote() async throws {
        nonisolated(unsafe) var requestCount = 0
        nonisolated(unsafe) var retryUserMessage: String?
        MockURLProtocol.handler = { request in
            requestCount += 1
            if requestCount == 1 {
                // First answer drops the %@ — must be rejected
                return TestAPI.response(body: TestAPI.translationsBody([("GREETING", "Hallo")]))(request)
            }
            let body = try JSONSerialization.jsonObject(with: request.bodyData ?? Data()) as? [String: Any]
            let messages = body?["messages"] as? [[String: Any]]
            retryUserMessage = messages?.first?["content"] as? String
            return TestAPI.response(body: TestAPI.translationsBody([("GREETING", "Hallo %@")]))(request)
        }

        let translator = Translator(provider: TestAPI.client())
        let outcome = try await translator.translate(gaps: [TestAPI.gap(key: "GREETING", source: "Hello %@")])

        #expect(requestCount == 2)
        #expect(outcome.translated.count == 1)
        #expect(outcome.translated.first?.value == "Hallo %@")
        #expect(outcome.failed.isEmpty)
        let note = try #require(retryUserMessage)
        #expect(note.contains("rejected"))
        #expect(note.contains("placeholders don't match"))
    }

    @Test func translatorFailsPersistentlyInvalidTranslation() async throws {
        MockURLProtocol.handler = { request in
            TestAPI.response(body: TestAPI.translationsBody([("COUNT", "Falsch ohne Specifier")]))(request)
        }

        let translator = Translator(provider: TestAPI.client())
        let outcome = try await translator.translate(gaps: [TestAPI.gap(key: "COUNT", source: "%d items")])

        #expect(outcome.translated.isEmpty)
        #expect(outcome.failed.count == 1)
        #expect(outcome.failed.first?.reason.contains("placeholders don't match") == true)
    }

    @Test func translatorFailsWhenKeyMissingFromResponse() async throws {
        MockURLProtocol.handler = { request in
            TestAPI.response(body: TestAPI.translationsBody([]))(request)
        }

        let translator = Translator(provider: TestAPI.client())
        let outcome = try await translator.translate(gaps: [TestAPI.gap(key: "GREETING", source: "Hello")])

        #expect(outcome.failed.count == 1)
        #expect(outcome.failed.first?.reason.contains("no value returned") == true)
    }
}
