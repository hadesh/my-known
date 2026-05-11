import Foundation

// MARK: - RAGOptions

/// RAG 查询选项配置
public struct RAGOptions {
    /// 返回的相关文档数量
    public var topK: Int = 5
    
    /// 搜索模式（全文、语义、混合）
    public var mode: SearchMode = .hybrid
    
    /// 最大上下文 token 预算（默认 8000）
    public var maxContextTokens: Int = 8000
    
    /// 默认初始化
    public init(topK: Int = 5, mode: SearchMode = .hybrid, maxContextTokens: Int = 8000) {
        self.topK = topK
        self.mode = mode
        self.maxContextTokens = maxContextTokens
    }
}

// MARK: - RAGPipeline

/// RAG (Retrieval-Augmented Generation) 流水线
/// 负责协调搜索、上下文构建和 LLM 生成
public struct RAGPipeline {
    public let searchEngine: SearchEngine
    public let llmAgent: LLMAgent
    public let fileManager: KnowledgeVaultFileManager
    
    /// 初始化 RAGPipeline
    /// - Parameters:
    ///   - searchEngine: 搜索引擎实例
    ///   - llmAgent: LLM Agent 实例
    ///   - fileManager: 文件管理器实例
    public init(searchEngine: SearchEngine, llmAgent: LLMAgent, fileManager: KnowledgeVaultFileManager) {
        self.searchEngine = searchEngine
        self.llmAgent = llmAgent
        self.fileManager = fileManager
    }
    
    /// 执行 RAG 查询
    /// 流程：搜索 → 加载 Entry → buildSystemPrompt → LLMAgent.chat
    /// - Parameters:
    ///   - question: 用户问题
    ///   - options: RAG 选项配置
    /// - Returns: 流式响应
    public func query(question: String, options: RAGOptions) async throws -> AsyncStream<String> {
        // 1. 执行搜索
        let searchResults = try await searchEngine.search(
            query: question,
            mode: options.mode,
            limit: options.topK
        )
        
        // 2. 加载 Entry 并构建上下文片段
        var contexts: [ContextSnippet] = []
        for result in searchResults {
            do {
                let entry = try await fileManager.readEntry(id: result.fileID)
                let snippet = ContextSnippet(
                    fileID: entry.id,
                    title: result.title ?? entry.title,
                    path: "",
                    content: entry.content
                )
                contexts.append(snippet)
            } catch {
                // 如果加载失败，使用搜索结果中的 snippet 作为 fallback
                let snippet = ContextSnippet(
                    fileID: result.fileID,
                    title: result.title,
                    path: "",
                    content: result.snippet
                )
                contexts.append(snippet)
            }
        }
        
        // 3. 根据 token 预算截断上下文
        let truncatedContexts = PromptBuilder.truncateContexts(
            contexts,
            maxTokens: options.maxContextTokens
        )
        
        // 4. 构建系统提示词
        let systemPrompt = PromptBuilder.buildSystemPrompt(contexts: truncatedContexts)
        
        // 5. 构建消息列表
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
                content: question,
                timestamp: Date(),
                isStreaming: false,
                citations: []
            )
        ]
        
        // 6. 调用 LLM Agent
        return try await llmAgent.chat(messages: messages)
    }
}
