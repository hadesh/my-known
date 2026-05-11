import SwiftUI
import KnowledgeVaultCore

// Browse 功能主视图
// iPad 使用 NavigationSplitView（左右分栏）
// iPhone 使用 NavigationStack（单栏导航）
struct BrowseView: View {
    // 环境注入的 FileManager
    @Environment(\.knowledgeVaultFileManager) var fileManager
    
    // 浏览模式：按主题或按日期
    @State private var browseMode: BrowseMode = .topics
    
    // 选中的 topic（用于导航到详情）
    @State private var selectedTopic: String?
    
    // 从 inbox 获取的所有 entries（用于提取 topics）
    @State private var allEntries: [Entry] = []
    
    // 加载状态
    @State private var isLoading = true
    
    // 浏览模式枚举
    enum BrowseMode: String, CaseIterable {
        case topics = "按主题"
        case daily = "按日期"
    }
    
    // 从 entries 中提取所有 topics（假设 topics 是特殊的 tag）
    private var topics: [String] {
        let allTags = allEntries.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    var body: some View {
        NavigationSplitView {
            // 左侧/顶层：根据模式显示不同列表
            Group {
                if browseMode == .topics {
                    TopicListView(
                        topics: topics,
                        entries: allEntries,
                        selectedTopic: selectedTopic,
                        onSelectTopic: { topic in
                            selectedTopic = topic
                        }
                    )
                } else {
                    DailyView(entries: allEntries)
                }
            }
            .navigationTitle("浏览")
            .toolbar {
                // 切换浏览模式的 Picker
                ToolbarItem {
                    Picker("浏览模式", selection: $browseMode) {
                        ForEach(BrowseMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        } detail: {
            // 右侧/下级：Entry 详情
            if let topic = selectedTopic {
                // 显示该 topic 下的 entries 列表
                TopicEntriesView(
                    topic: topic,
                    entries: allEntries.filter { $0.tags.contains(topic) }
                )
            } else {
                // 未选择 topic 时显示提示
                ContentUnavailableView(
                    "选择主题",
                    systemImage: "folder",
                    description: Text("从左侧选择一个主题查看相关条目")
                )
            }
        }
        .task {
            // 加载所有 entries
            await loadEntries()
        }
    }
    
    // 加载 entries
    private func loadEntries() async {
        isLoading = true
        do {
            // 从 inbox 获取所有 entries
            allEntries = try await fileManager.listEntries(in: .inbox)
        } catch {
            print("加载条目失败: \(error)")
        }
        isLoading = false
    }
}

// Topic 下的 entries 列表视图（辅助视图）
struct TopicEntriesView: View {
    let topic: String
    let entries: [Entry]
    
    @State private var selectedEntry: Entry?
    
    var body: some View {
        NavigationStack {
            List(entries) { entry in
                NavigationLink(value: entry) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title ?? "无标题")
                            .font(.headline)
                        Text(entry.content.prefix(100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationTitle(topic)
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }
}

#Preview {
    BrowseView()
}