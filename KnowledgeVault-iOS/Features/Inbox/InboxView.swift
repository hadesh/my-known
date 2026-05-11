import SwiftUI
import KnowledgeVaultCore

// 收件箱视图，展示所有待处理的条目
struct InboxView: View {
    // ViewModel 使用 @State（iOS 17+ 的 @Observable 模式）
    @State private var viewModel: InboxViewModel
    
    // 创建新条目的弹窗状态
    @State private var showingCreateEntry = false
    
    // 从环境获取 AppState 和 FileManager
    @Environment(AppState.self) private var appState
    
    // 初始化
    init(fileManager: KnowledgeVaultFileManager) {
        // 初始化 ViewModel
        let vm = InboxViewModel(fileManager: fileManager)
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    // 初次加载时显示加载指示器
                    ProgressView("加载中...")
                } else if viewModel.entries.isEmpty {
                    // 空状态提示
                    ContentUnavailableView(
                        "收件箱为空",
                        systemImage: "tray",
                        description: Text("点击右上角的 + 按钮创建新条目")
                    )
                } else {
                    // 条目列表
                    entryList
                }
            }
            .navigationTitle("收件箱")
            .toolbar {
                // 右上角添加按钮
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateEntry = true
                    } label: {
                        Label("新建", systemImage: "plus")
                    }
                }
            }
            // 创建条目弹窗
            .sheet(isPresented: $showingCreateEntry) {
                CreateEntryView(onSave: { content, type, source in
                    Task {
                        try? await viewModel.createEntry(
                            content: content,
                            type: type,
                            source: source
                        )
                    }
                })
            }
            // 页面加载时自动刷新条目列表
            .task {
                await viewModel.loadEntries()
            }
        }
    }
    
    // 条目列表视图
    private var entryList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                EntryRow(entry: entry)
            }
            // 左滑删除
            .onDelete { indexSet in
                for index in indexSet {
                    let entry = viewModel.entries[index]
                    Task {
                        try? await viewModel.deleteEntry(entry)
                    }
                }
            }
        }
        // 下拉刷新
        .refreshable {
            await viewModel.loadEntries()
        }
    }
}

// 条目行视图组件
struct EntryRow: View {
    let entry: Entry
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: iconForType(entry.type))
                .font(.title2)
                .foregroundStyle(colorForType(entry.type))
                .frame(width: 32)
            
            // 内容信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题（如果没有标题则显示"无标题"）
                Text(entry.title ?? "无标题")
                    .font(.headline)
                    .lineLimit(1)
                
                // 相对时间
                Text(entry.created, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 状态标识
            statusBadge(for: entry.status)
        }
        .padding(.vertical, 4)
    }
    
    // 根据条目类型返回对应图标
    private func iconForType(_ type: EntryType) -> String {
        switch type {
        case .note: return "note.text"
        case .screenshot: return "camera"
        case .voice: return "waveform"
        case .link: return "link"
        case .file: return "doc"
        }
    }
    
    // 根据条目类型返回对应颜色
    private func colorForType(_ type: EntryType) -> Color {
        switch type {
        case .note: return .blue
        case .screenshot: return .green
        case .voice: return .purple
        case .link: return .orange
        case .file: return .gray
        }
    }
    
    // 状态标识徽章
    private func statusBadge(for status: EntryStatus) -> some View {
        Group {
            if status != .raw {
                Text(statusBadgeText(status))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusBadgeColor(status))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }
    
    // 状态徽章文本
    private func statusBadgeText(_ status: EntryStatus) -> String {
        switch status {
        case .raw: return ""
        case .reviewed: return "已审阅"
        case .organized: return "已整理"
        }
    }
    
    // 状态徽章颜色
    private func statusBadgeColor(_ status: EntryStatus) -> Color {
        switch status {
        case .raw: return .clear
        case .reviewed: return .orange
        case .organized: return .green
        }
    }
}

// 预览
#Preview {
    InboxView(fileManager: MockFileManager())
}

// Mock FileManager 用于预览
private struct MockFileManager: KnowledgeVaultFileManager {
    var vaultURL: URL { URL.documentsDirectory }
    
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry {
        Entry(
            id: "20260509-153021-test",
            title: content,
            content: content,
            type: type,
            source: source,
            status: .raw,
            tags: [],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "inbox/test.md",
            attachmentURLs: []
        )
    }
    
    func readEntry(id: String) async throws -> Entry {
        throw NSError(domain: "Mock", code: 0)
    }
    
    func updateEntry(id: String, content: String, tags: [String]) async throws {}
    
    func moveEntry(id: String, toTopic: String) async throws {}
    
    func listEntries(in directory: VaultDirectory) async throws -> [Entry] {
        [
            Entry(
                id: "20260509-153021-test1",
                title: "示例笔记",
                content: "这是一条示例笔记内容",
                type: .note,
                source: .manual,
                status: .raw,
                tags: [],
                summary: nil,
                created: Date().addingTimeInterval(-3600),
                updated: Date().addingTimeInterval(-3600),
                relativePath: "inbox/test1.md",
                attachmentURLs: []
            ),
            Entry(
                id: "20260509-153021-test2",
                title: "网页链接",
                content: "https://example.com",
                type: .link,
                source: .clipboard,
                status: .reviewed,
                tags: ["技术"],
                summary: nil,
                created: Date().addingTimeInterval(-7200),
                updated: Date().addingTimeInterval(-7200),
                relativePath: "inbox/test2.md",
                attachmentURLs: []
            )
        ]
    }
    
    func search(query: String, mode: SearchMode) async throws -> [SearchResult] { [] }
    
    func deleteEntry(id: String) async throws {}
    
    func exportEntry(id: String) async throws -> URL { URL.documentsDirectory }
}