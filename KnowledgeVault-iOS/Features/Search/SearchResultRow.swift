import SwiftUI
import KnowledgeVaultCore

/// 搜索结果行视图
struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题（优先显示 title，否则显示 fileID）
            Text(result.title ?? result.fileID)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(result.snippet)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                Text(String(format: "%.0f%%", result.score * 100))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                
                if !result.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(result.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchResultRow(
        result: SearchResult(
            fileID: "test-1",
            title: "SwiftUI 学习笔记",
            snippet: "SwiftUI 是 Apple 推出的现代化 UI 框架，使用声明式语法构建用户界面...",
            score: 0.92,
            searchMode: .hybrid,
            tags: ["SwiftUI", "iOS", "学习"],
            created: Date()
        )
    )
}