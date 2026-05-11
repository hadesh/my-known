import Foundation

public struct LLMConfig: Codable {
    public var defaultProvider: String
    public var model: String
    public var maxTokens: Int
    public var temperature: Double
    
    public init(defaultProvider: String = "openai", model: String = "gpt-4o", maxTokens: Int = 4096, temperature: Double = 0.7) {
        self.defaultProvider = defaultProvider
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}