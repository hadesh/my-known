import SwiftUI
import KnowledgeVaultCore

/// AI 聊天界面的 ViewModel
/// 使用 @Observable 实现响应式状态管理（iOS 17+）
@Observable final class ChatViewModel {
    /// 聊天消息列表
    var messages: [ChatMessage] = []
    
    /// 是否正在流式输出
    var isStreaming: Bool = false
    
    /// 当前流式输出的临时缓冲内容
    var currentStreamingContent: String = ""
    
    /// RAG Pipeline 实例（用于查询知识库）
    private let ragPipeline: RAGPipeline
    
    /// 初始化 ViewModel
    /// - Parameter ragPipeline: RAG 流水线实例
    init(ragPipeline: RAGPipeline) {
        self.ragPipeline = ragPipeline
    }
    
    /// 发送用户消息并获取 AI 流式响应
    /// - Parameter text: 用户输入的文本
    func sendMessage(_ text: String) async throws {
        // 1. 构造用户消息并添加到消息列表
        let userMessage = ChatMessage(
            id: UUID(),
            role: .user,
            content: text,
            timestamp: Date(),
            isStreaming: false,
            citations: []
        )
        messages.append(userMessage)
        
        // 2. 开始流式输出状态
        isStreaming = true
        currentStreamingContent = ""
        
        // 3. 调用 RAG Pipeline 查询
        let options = RAGOptions(topK: 5, mode: .hybrid, maxContextTokens: 8000)
        let stream = try await ragPipeline.query(question: text, options: options)
        
        // 4. 收集流式输出内容并更新缓冲
        for await token in stream {
            currentStreamingContent += token
        }
        
        // 5. 流式输出结束后，追加完整的 assistant 消息
        let assistantMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: currentStreamingContent,
            timestamp: Date(),
            isStreaming: false,
            citations: []
        )
        messages.append(assistantMessage)
        
        // 6. 清空缓冲并结束流式状态
        currentStreamingContent = ""
        isStreaming = false
    }
    
    /// 清空聊天历史
    func clearHistory() {
        messages.removeAll()
    }
}