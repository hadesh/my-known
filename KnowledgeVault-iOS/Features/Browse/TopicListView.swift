import SwiftUI
import KnowledgeVaultCore

// 主题列表视图
// 显示所有 topics，每个 topic 显示名称和条目数量徽章
struct TopicListView: View {
    let topics: [String]
    let entries: [Entry]
    let selectedTopic: String?
    let onSelectTopic: (String) -> Void
    
    // 计算每个 topic 的条目数量
    private func entryCount(for topic: String) -> Int {
        entries.filter { $0.tags.contains(topic) }.count
    }
    
    var body: some View {
        List(topics, id: \.self) { topic in
            // 每个 topic 行
            HStack {
                // topic 名称
                Text(topic)
                    .font(.headline)
                
                Spacer()
                
                // 条目数量徽章
                if entryCount(for: topic) > 0 {
                    Text("\(entryCount(for: topic))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            .contentShape(Rectangle()) // 确保整行可点击
            .onTapGesture {
                onSelectTopic(topic)
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    TopicListView(
        topics: ["Swift", "iOS开发", "设计模式"],
        entries: [],
        selectedTopic: nil,
        onSelectTopic: { _ in }
    )
}