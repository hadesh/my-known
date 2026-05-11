import Foundation

/// LLM Provider 协议定义
public protocol LLMProvider: Sendable {
    nonisolated var name: String { get }
    nonisolated var baseURL: URL { get }
    nonisolated var apiKey: String { get }
    nonisolated var embeddingModel: String? { get }
    
    func chatCompletion(
        messages: [ChatMessage],
        model: String,
        temperature: Double
    ) async throws -> AsyncStream<String>
    
    func embedding(
        text: String,
        model: String
    ) async throws -> [Float]
}

/// LLM Provider 错误类型
public enum LLMProviderError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(Error)
    case networkError(Error)
    case authenticationError
    case rateLimited
    case serverError(Int)
    case notSupported(String)
}

/// Provider 配置
public struct ProviderConfig: Codable, Sendable {
    public let name: String
    public let baseURL: String
    public let defaultModel: String
    public let embeddingModel: String?
    
    public init(
        name: String,
        baseURL: String,
        defaultModel: String,
        embeddingModel: String? = nil
    ) {
        self.name = name
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.embeddingModel = embeddingModel
    }
}
