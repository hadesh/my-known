import Foundation

public actor AnthropicProvider: LLMProvider {
    public let name: String
    public let baseURL: URL
    public let apiKey: String
    public let defaultModel: String
    nonisolated public let embeddingModel: String?
    
    private let urlSession: URLSession
    private let sseParser = SSEParser()
    
    public init(
        name: String = "anthropic",
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        defaultModel: String = "claude-3-sonnet-20240229",
        embeddingModel: String? = nil
    ) {
        self.name = name
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.embeddingModel = embeddingModel
        self.urlSession = URLSession(configuration: .default)
    }
    
    public func chatCompletion(
        messages: [ChatMessage],
        model: String,
        temperature: Double
    ) async throws -> AsyncStream<String> {
        let endpoint = baseURL.appendingPathComponent("messages")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        var systemMessage: String? = nil
        var userMessages: [[String: Any]] = []
        
        for message in messages {
            if message.role == .system {
                systemMessage = message.content
            } else {
                userMessages.append([
                    "role": message.role.rawValue,
                    "content": message.content
                ])
            }
        }
        
        var body: [String: Any] = [
            "model": model,
            "messages": userMessages,
            "max_tokens": 4096,
            "temperature": temperature,
            "stream": true
        ]
        
        if let system = systemMessage {
            body["system"] = system
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw LLMProviderError.authenticationError
            } else if httpResponse.statusCode == 429 {
                throw LLMProviderError.rateLimited
            } else {
                throw LLMProviderError.serverError(httpResponse.statusCode)
            }
        }
        
        let stream = await sseParser.parseStream(from: response, bytes: bytes)
        
        return AsyncStream { continuation in
            Task {
                do {
                    for try await content in stream {
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    public func embedding(text: String, model: String) async throws -> [Float] {
        // Anthropic 官方不提供 Embedding API
        throw LLMProviderError.notSupported("Anthropic does not provide an embedding API. Use OpenAI or other providers for embeddings.")
    }
}
