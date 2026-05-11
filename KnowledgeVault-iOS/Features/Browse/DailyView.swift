import SwiftUI
import KnowledgeVaultCore

// 每日视图
// 按 created 日期分组，Section 展示每天的条目
struct DailyView: View {
    let entries: [Entry]
    
    // 按日期分组 entries
    private var entriesByDate: [(Date, [Entry])] {
        let grouped = Dictionary(grouping: entries) { entry in
            // 使用日历去除时间部分，只保留日期
            Calendar.current.startOfDay(for: entry.created)
        }
        
        // 按日期降序排序（最近的在前）
        return grouped.sorted { $0.key > $1.key }
    }
    
    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entriesByDate, id: \.0) { date, dateEntries in
                    // 日期 Section
                    Section(header: Text(dateFormatter.string(from: date))) {
                        ForEach(dateEntries) { entry in
                            NavigationLink(value: entry) {
                                VStack(alignment: .leading, spacing: 4) {
                                    // 标题
                                    Text(entry.title ?? "无标题")
                                        .font(.headline)
                                    
                                    // 内容摘要（前 100 字符）
                                    Text(entry.content.prefix(100))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    // 标签（横向显示）
                                    if !entry.tags.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                            if entry.tags.count > 3 {
                                                Text("+\(entry.tags.count - 3)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("按日期浏览")
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }
}

#Preview {
    DailyView(entries: [])
}