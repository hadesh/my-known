import Foundation

public struct OrganizationResult: Codable {
    public let entryID: String
    public let suggestedTitle: String
    public let suggestedTags: [String]
    public let suggestedTopic: String
    
    public init(
        entryID: String,
        suggestedTitle: String,
        suggestedTags: [String],
        suggestedTopic: String
    ) {
        self.entryID = entryID
        self.suggestedTitle = suggestedTitle
        self.suggestedTags = suggestedTags
        self.suggestedTopic = suggestedTopic
    }
}

public actor LLMAgent {
    private var config: LLMConfig
    private var providers: [String: any LLMProvider] = [:]
    private var defaultProviderName: String
    
    public init(config: LLMConfig) {
        self.config = config
        self.defaultProviderName = config.defaultProvider
    }
    
    public func registerProvider(_ provider: some LLMProvider) {
        providers[provider.name] = provider
    }

    public func clearProviders() {
        providers.removeAll()
    }
    
    public func setDefaultProvider(_ name: String) {
        defaultProviderName = name
    }
    
    private func getDefaultProvider() async throws -> any LLMProvider {
        if let provider = providers[defaultProviderName] {
            return provider
        }
        
        let availableProviders = providers.keys.sorted()
        if let firstProvider = availableProviders.first,
           let provider = providers[firstProvider] {
            return provider
        }
        
        throw LLMProviderError.apiError("No LLM provider available")
    }
    
    public func chat(messages: [ChatMessage]) async throws -> AsyncStream<String> {
        let provider = try await getDefaultProvider()
        return try await provider.chatCompletion(
            messages: messages,
            model: config.model,
            temperature: config.temperature
        )
    }
    
    public func embed(text: String) async throws -> [Float] {
        let provider = try await getDefaultProvider()
        let embeddingModel = await provider.embeddingModel ?? "text-embedding-3-small"
        return try await provider.embedding(text: text, model: embeddingModel)
    }
    
    public func organizeEntries(entries: [Entry]) async throws -> [OrganizationResult] {
        let systemPrompt = """
        You are an intelligent organizer. For each entry provided, analyze its content and suggest:
        1. A concise, descriptive title (max 100 characters)
        2. Relevant tags (3-7 tags, each max 30 characters)
        3. A topic/category that best describes the entry
        
        Return ONLY a JSON array in the following format:
        [
          {
            "entryID": "<entry_id>",
            "suggestedTitle": "<title>",
            "suggestedTags": ["tag1", "tag2", ...],
            "suggestedTopic": "<topic>"
          }
        ]
        """
        
        let entriesText = entries.map { entry in
            """
            Entry ID: \(entry.id)
            Content: \(entry.content.prefix(2000))
            """
        }.joined(separator: "\n---\n")
        
        let userPrompt = "Please organize the following entries:\n\n\(entriesText)"
        
        let messages: [ChatMessage] = [
            ChatMessage(
                id: UUID(),
                role: .system,
                content: systemPrompt,
                timestamp: Date(),
                isStreaming: false,
                citations: []
            ),
            ChatMessage(
                id: UUID(),
                role: .user,
                content: userPrompt,
                timestamp: Date(),
                isStreaming: false,
                citations: []
            )
        ]
        
        let stream = try await chat(messages: messages)
        var fullResponse = ""
        
        for await chunk in stream {
            fullResponse.append(chunk)
        }
        
        guard let data = fullResponse.data(using: .utf8) else {
            throw LLMProviderError.decodingError(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Failed to convert response to data")
            ))
        }
        
        do {
            let results = try JSONDecoder().decode([OrganizationResult].self, from: data)
            return results
        } catch {
            let cleanedResponse = fullResponse
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let cleanedData = cleanedResponse.data(using: .utf8) {
                return try JSONDecoder().decode([OrganizationResult].self, from: cleanedData)
            }
            
            throw LLMProviderError.decodingError(error)
        }
    }
    
    public func answer(question: String, context: [String]) async throws -> AsyncStream<String> {
        let contextText = context.joined(separator: "\n\n")
        
        let systemPrompt = """
        You are a helpful assistant answering questions based on the provided context.
        Use only the information from the context to answer. If the context doesn't contain enough information, say so.
        Be concise but thorough in your answers.
        """
        
        let userPrompt = """
        Context:
        \(contextText)
        
        Question: \(question)
        """
        
        let messages: [ChatMessage] = [
            ChatMessage(
                id: UUID(),
                role: .system,
                content: systemPrompt,
                timestamp: Date(),
                isStreaming: false,
                citations: []
            ),
            ChatMessage(
                id: UUID(),
                role: .user,
                content: userPrompt,
                timestamp: Date(),
                isStreaming: false,
                citations: []
            )
        ]
        
        return try await chat(messages: messages)
    }
    
    public func fallbackChat(messages: [ChatMessage]) async throws -> AsyncStream<String> {
        let availableProviders = providers.keys.sorted()
        
        for providerName in availableProviders {
            if providerName == defaultProviderName {
                continue
            }
            
            if let provider = providers[providerName] {
                do {
                    return try await provider.chatCompletion(
                        messages: messages,
                        model: config.model,
                        temperature: config.temperature
                    )
                } catch {
                    continue
                }
            }
        }
        
        throw LLMProviderError.apiError("No fallback provider available")
    }
}
