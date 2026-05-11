import Foundation

// MARK: - ContextSnippet

/// 上下文片段，用于 RAG 提示构建
public struct ContextSnippet {
    public let fileID: String
    public let title: String?
    public let path: String
    public let content: String
    
    public init(fileID: String, title: String?, path: String, content: String) {
        self.fileID = fileID
        self.title = title
        self.path = path
        self.content = content
    }
}

// MARK: - PromptBuilder

/// 提示构建器，负责构建 RAG 系统提示词
public struct PromptBuilder {
    
    /// 构建系统提示词
    /// - Parameter contexts: 上下文片段列表
    /// - Returns: 系统提示词字符串
    public static func buildSystemPrompt(contexts: [ContextSnippet]) -> String {
        if contexts.isEmpty {
            return """
            You are a helpful assistant. Answer questions based on your knowledge. If you don't know the answer, say so honestly.
            """
        }
        
        var promptParts: [String] = []
        
        promptParts.append("""
        You are a helpful assistant answering questions based on the provided context information.
        
Use only the information from the provided context to answer questions. If the context doesn't contain enough information to answer the question, say so honestly.
        
When answering:
- Be concise but thorough
- Cite relevant sources when appropriate
- If multiple sources are relevant, synthesize the information
""")
        
        promptParts.append("\n---\n")
        promptParts.append("Context Information:\n")
        
        for (index, snippet) in contexts.enumerated() {
            promptParts.append("\n[Source \(index + 1)]")
            if let title = snippet.title, !title.isEmpty {
                promptParts.append(" Title: \(title)")
            }
            promptParts.append("\n\(snippet.content)")
            promptParts.append("\n---")
        }
        
        return promptParts.joined()
    }
    
    /// 估算文本的 token 数量
    /// - Parameter text: 输入文本
    /// - Returns: 估算的 token 数量（字符数 / 4）
    public static func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
    
    /// 根据 token 预算截断上下文片段
    /// - Parameters:
    ///   - contexts: 原始上下文片段列表
    ///   - maxTokens: 最大 token 预算
    /// - Returns: 截断后的上下文片段列表
    public static func truncateContexts(_ contexts: [ContextSnippet], maxTokens: Int) -> [ContextSnippet] {
        var result: [ContextSnippet] = []
        var currentTokenCount = 0
        
        for snippet in contexts {
            let snippetTokens = estimateTokens(snippet.content)
            
            // 如果当前片段加上后仍不超过预算
            if currentTokenCount + snippetTokens <= maxTokens {
                result.append(snippet)
                currentTokenCount += snippetTokens
            } else {
                // 如果还有剩余空间，尝试截断内容
                let remainingTokens = maxTokens - currentTokenCount
                if remainingTokens > 50 { // 至少保留 50 tokens
                    let maxChars = remainingTokens * 4
                    let truncatedContent = String(snippet.content.prefix(maxChars))
                    let truncatedSnippet = ContextSnippet(
                        fileID: snippet.fileID,
                        title: snippet.title,
                        path: snippet.path,
                        content: truncatedContent
                    )
                    result.append(truncatedSnippet)
                    break
                } else {
                    // 空间不足，跳过
                    break
                }
            }
        }
        
        return result
    }
}
