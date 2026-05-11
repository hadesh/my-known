import Foundation

public actor OpenAIProvider: LLMProvider {
    public let name: String
    public let baseURL: URL
    public let apiKey: String
    public let defaultModel: String
    nonisolated public var embeddingModel: String? { _embeddingModel }
    private let _embeddingModel: String
    
    private let urlSession: URLSession
    private let sseParser = SSEParser()
    
    public init(
        name: String = "openai",
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        defaultModel: String = "gpt-4o",
        embeddingModel: String = "text-embedding-3-small"
    ) {
        self.name = name
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self._embeddingModel = embeddingModel
        self.urlSession = URLSession(configuration: .default)
    }
    
    public func chatCompletion(
        messages: [ChatMessage],
        model: String,
        temperature: Double
    ) async throws -> AsyncStream<String> {
        let endpoint = baseURL.appendingPathComponent("chat/completions")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let messagesArray: [[String: String]] = messages.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": messagesArray,
            "temperature": temperature,
            "stream": true
        ]
        
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
        let endpoint = baseURL.appendingPathComponent("embeddings")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "input": text
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        
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
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let embeddingArray = firstData["embedding"] as? [Double] else {
            throw LLMProviderError.decodingError(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Failed to decode embedding response")
            ))
        }
        
        return embeddingArray.map { Float($0) }
    }
}
