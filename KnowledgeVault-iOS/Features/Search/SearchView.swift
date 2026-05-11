import SwiftUI
import KnowledgeVaultCore

/// 搜索界面视图
struct SearchView: View {
    // MARK: - 状态属性
    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var searchMode: SearchMode = .hybrid
    @State private var isSearching: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil
    
    // 文件管理器（从环境注入）
    @Environment(\.knowledgeVaultFileManager) private var fileManager: any KnowledgeVaultFileManager
    
    // MARK: - 视图主体
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("搜索模式", selection: $searchMode) {
                    Text("全文搜索").tag(SearchMode.fulltext)
                    Text("混合搜索").tag(SearchMode.hybrid)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if results.isEmpty && !isSearching {
                    emptyStateView
                } else {
                    resultList
                }
            }
            .navigationTitle("搜索")
            .searchable(text: $query, prompt: "输入关键词搜索...")
            .onChange(of: query) { _, newValue in
                handleQueryChange(newValue)
            }
            .onChange(of: searchMode) { _, _ in
                if !query.isEmpty {
                    Task { await performSearch() }
                }
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        ContentUnavailableView(
            query.isEmpty ? "输入关键词开始搜索" : "暂无结果",
            systemImage: "magnifyingglass",
            description: Text(query.isEmpty ? "支持全文搜索和智能混合搜索" : "未找到匹配的知识条目")
        )
    }
    
    // MARK: - 结果列表
    private var resultList: some View {
        List {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(results) { result in
                    SearchResultRow(result: result)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 搜索逻辑
    
    /// 处理查询词变化（带 debounce）
    private func handleQueryChange(_ newQuery: String) {
        debounceTask?.cancel()
        
        if newQuery.isEmpty {
            results = []
            isSearching = false
            return
        }
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            guard !Task.isCancelled else { return }
            guard newQuery == query else { return } // 防止竞态
            
            await performSearch()
        }
    }
    
    /// 执行搜索
    private func performSearch() async {
        guard !query.isEmpty else { return }
        
        isSearching = true
        
        do {
            let searchResults = try await fileManager.search(query: query, mode: searchMode)
            
            guard query == query && searchMode == searchMode else { return }
            
            results = searchResults
        } catch {
            results = []
            print("搜索失败: \(error.localizedDescription)")
        }
        
        isSearching = false
    }
}

// MARK: - 环境键（用于注入 FileManager）

struct KnowledgeVaultFileManagerKey: EnvironmentKey {
    static let defaultValue: any KnowledgeVaultFileManager = MockFileManager()
}

extension EnvironmentValues {
    var knowledgeVaultFileManager: any KnowledgeVaultFileManager {
        get { self[KnowledgeVaultFileManagerKey.self] }
        set { self[KnowledgeVaultFileManagerKey.self] = newValue }
    }
}

// MARK: - Mock FileManager（预览用）

private struct MockFileManager: KnowledgeVaultFileManager {
    var vaultURL: URL { URL(fileURLWithPath: "/mock") }
    
    func search(query: String, mode: SearchMode) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return [
            SearchResult(
                fileID: "test-1",
                title: "测试标题",
                snippet: "这是一段测试内容摘要，包含了关键词的上下文信息...",
                score: 0.85,
                searchMode: mode,
                tags: ["测试", "示例"],
                created: Date()
            )
        ]
    }
    
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry {
        fatalError("Not implemented")
    }
    
    func readEntry(id: String) async throws -> Entry {
        fatalError("Not implemented")
    }
    
    func updateEntry(id: String, content: String, tags: [String]) async throws {
        fatalError("Not implemented")
    }
    
    func moveEntry(id: String, toTopic: String) async throws {
        fatalError("Not implemented")
    }
    
    func listEntries(in directory: VaultDirectory) async throws -> [Entry] {
        fatalError("Not implemented")
    }
    
    func deleteEntry(id: String) async throws {
        fatalError("Not implemented")
    }
    
    func exportEntry(id: String) async throws -> URL {
        fatalError("Not implemented")
    }
}

// MARK: - 预览

#Preview {
    SearchView()
}