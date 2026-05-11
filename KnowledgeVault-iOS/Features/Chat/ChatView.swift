import SwiftUI
import KnowledgeVaultCore

/// AI 聊天界面主视图
struct ChatView: View {
    /// 聊天 ViewModel（使用 @Observable 状态管理）
    var viewModel: ChatViewModel
    
    /// 用户输入文本
    @State private var input: String = ""
    
    /// 光标闪烁动画状态
    @State private var showCursor: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表区域
            messageList
            
            // 底部输入栏
            inputBar
        }
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 消息列表
    
    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 遍历历史消息
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    // 流式输出中的临时气泡
                    if viewModel.isStreaming && !viewModel.currentStreamingContent.isEmpty {
                        streamingBubble
                            .id("streaming")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // 新消息到达时自动滚动到底部
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.currentStreamingContent) { _, _ in
                // 流式内容更新时滚动到底部
                scrollToBottom(proxy)
            }
        }
    }
    
    // MARK: - 流式输出临时气泡
    
    @ViewBuilder
    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI 图标
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // 流式内容（Markdown 渲染）
                MarkdownRenderer(content: viewModel.currentStreamingContent)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                
                // 光标动画
                cursorIndicator
            }
            
            Spacer()
        }
    }
    
    // MARK: - 光标指示器
    
    @ViewBuilder
    private var cursorIndicator: some View {
        Text("|")
            .font(.body)
            .foregroundColor(.blue)
            .opacity(showCursor ? 1 : 0)
            .onAppear {
                // 启动光标闪烁动画（0.5s 间隔）
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                    showCursor.toggle()
                    // 流式输出结束时停止动画
                    if !viewModel.isStreaming {
                        timer.invalidate()
                    }
                }
            }
    }
    
    // MARK: - 底部输入栏
    
    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("问点什么…", text: $input)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isStreaming)
            
            // 发送按钮
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isStreaming || input.isEmpty ? .gray : .blue)
            }
            .disabled(viewModel.isStreaming || input.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 辅助方法
    
    /// 发送用户消息
    private func sendMessage() {
        guard !input.isEmpty else { return }
        
        let text = input
        input = ""
        
        Task {
            try? await viewModel.sendMessage(text)
        }
    }
    
    /// 滚动到消息列表底部
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // 如果有流式输出临时气泡，优先滚动到它
        if viewModel.isStreaming {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        } else if let lastMessage = viewModel.messages.last {
            // 否则滚动到最后一条消息
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Preview

private struct PreviewSearchEngine: SearchEngine {
    func indexFile(_ file: MarkdownFile) async throws {}
    func updateIndex(fileID: String) async throws {}
    func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult] { [] }
    func rebuildIndex() async throws {}
}

private final class PreviewFileManager: KnowledgeVaultFileManager {
    var vaultURL: URL { URL(fileURLWithPath: "/tmp/preview") }
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry {
        Entry(id: "preview", content: content, type: type, source: source,
              status: .raw, created: Date(), updated: Date(), relativePath: "")
    }
    func readEntry(id: String) async throws -> Entry {
        Entry(id: id, content: "", type: .note, source: .manual,
              status: .raw, created: Date(), updated: Date(), relativePath: "")
    }
    func updateEntry(id: String, content: String, tags: [String]) async throws {}
    func moveEntry(id: String, toTopic: String) async throws {}
    func listEntries(in directory: VaultDirectory) async throws -> [Entry] { [] }
    func search(query: String, mode: SearchMode) async throws -> [SearchResult] { [] }
    func deleteEntry(id: String) async throws {}
    func exportEntry(id: String) async throws -> URL { URL(fileURLWithPath: "/tmp") }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel(ragPipeline: RAGPipeline(
            searchEngine: PreviewSearchEngine(),
            llmAgent: LLMAgent(config: LLMConfig()),
            fileManager: PreviewFileManager()
        )))
    }
}