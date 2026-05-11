import SwiftUI
import KnowledgeVaultCore

/// 聊天消息气泡组件
struct ChatMessageBubble: View {
    /// 消息数据
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // AI 图标（左侧）
                avatarIcon
            }
            
            // 消息内容气泡
            bubbleContent
            
            if message.role == .user {
                // 用户头像（右侧）
                userIcon
            }
        }
        .contextMenu {
            // 长按复制选项
            Button {
                copyMessage()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
    
    // MARK: - 消息内容气泡
    
    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            // 消息内容
            if message.role == .user {
                // 用户消息：纯文本显示
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // AI 消息：Markdown 渲染
                MarkdownRenderer(content: message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // 时间戳（小字体显示）
            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
    }
    
    // MARK: - AI 头像图标
    
    @ViewBuilder
    private var avatarIcon: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 20))
            .foregroundColor(.gray)
            .frame(width: 32, height: 32)
            .background(Color.gray.opacity(0.1))
            .clipShape(Circle())
    }
    
    // MARK: - 用户头像图标
    
    @ViewBuilder
    private var userIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 20))
            .foregroundColor(.blue)
            .frame(width: 32, height: 32)
            .background(Color.blue.opacity(0.1))
            .clipShape(Circle())
    }
    
    // MARK: - 辅助方法
    
    /// 复制消息内容到剪贴板
    private func copyMessage() {
        UIPasteboard.general.string = message.content
    }
    
    /// 格式化时间戳显示
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // 用户消息示例
        ChatMessageBubble(message: ChatMessage(
            id: UUID(),
            role: .user,
            content: "什么是 RAG 技术？",
            timestamp: Date(),
            isStreaming: false,
            citations: []
        ))
        
        // AI 消息示例
        ChatMessageBubble(message: ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "RAG（**Retrieval-Augmented Generation**）是一种结合检索和生成的新技术。\n\n它通过检索相关文档来增强 LLM 的上下文，提高回答的准确性。",
            timestamp: Date(),
            isStreaming: false,
            citations: []
        ))
    }
    .padding()
}