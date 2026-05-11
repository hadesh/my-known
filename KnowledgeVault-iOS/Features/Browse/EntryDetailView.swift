import SwiftUI
import KnowledgeVaultCore

// 条目详情视图
// 上方：MarkdownRenderer 渲染内容
// 下方：tags 横向滚动
// toolbar：编辑按钮、分享按钮
struct EntryDetailView: View {
    // 环境注入的 FileManager
    @Environment(\.knowledgeVaultFileManager) private var fileManager: any KnowledgeVaultFileManager
    
    // 当前条目
    let entry: Entry
    
    // 编辑模式状态
    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var editedTags: [String] = []
    
    // 分享状态
    @State private var showShareSheet = false
    
    // 保存状态
    @State private var isSaving = false
    
    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 元数据区域
                metadataSection
                
                // 内容区域
                contentSection
                
                // 标签区域
                tagsSection
            }
            .padding()
        }
        .navigationTitle(entry.title ?? "条目详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 编辑按钮
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "保存" : "编辑") {
                    if isEditing {
                        // 保存编辑
                        saveEdit()
                    } else {
                        // 进入编辑模式
                        startEdit()
                    }
                }
                .disabled(isSaving)
            }
            
            // 分享按钮
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isEditing)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            // 分享界面
            ShareSheet(items: [entry.content])
        }
        .onAppear {
            // 初始化编辑状态的内容
            editedContent = entry.content
            editedTags = entry.tags
        }
    }
    
    // 元数据区域
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 类型图标
            HStack {
                Image(systemName: typeIcon)
                    .foregroundColor(.blue)
                Text(entry.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 创建时间
                Text(dateFormatter.string(from: entry.created))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 来源和状态
            HStack {
                Label(entry.source.rawValue, systemImage: sourceIcon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(entry.status.rawValue, systemImage: statusIcon)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.bottom, 8)
    }
    
    // 内容区域
    private var contentSection: some View {
        Group {
            if isEditing {
                // 编辑模式：TextEditor
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                    
                    TextEditor(text: $editedContent)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            } else {
                // 查看模式：MarkdownRenderer
                MarkdownRenderer(content: entry.content)
            }
        }
    }
    
    // 标签区域
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
            
            if isEditing {
                // 编辑模式：可编辑的标签列表
                VStack(alignment: .leading, spacing: 8) {
                    // 当前标签
                    FlowLayout(spacing: 8) {
                        ForEach(editedTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                
                                Button {
                                    // 删除标签
                                    editedTags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    
                    // 添加标签按钮
                    Button {
                        // 添加空标签（实际应用中应该用 TextField 或 Alert）
                        editedTags.append("新标签")
                    } label: {
                        Label("添加标签", systemImage: "plus")
                            .font(.caption)
                    }
                }
            } else {
                // 查看模式：横向滚动标签
                if entry.tags.isEmpty {
                    Text("无标签")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 开始编辑
    private func startEdit() {
        editedContent = entry.content
        editedTags = entry.tags
        isEditing = true
    }
    
    // 保存编辑
    private func saveEdit() {
        isSaving = true
        
        Task {
            do {
                // 调用 FileManager 更新条目
                try await fileManager.updateEntry(
                    id: entry.id,
                    content: editedContent,
                    tags: editedTags
                )
                
                // 退出编辑模式
                isEditing = false
            } catch {
                print("保存失败: \(error)")
                // 实际应用中应该显示错误提示
            }
            
            isSaving = false
        }
    }
    
    // 类型图标
    private var typeIcon: String {
        switch entry.type {
        case .note: return "note.text"
        case .screenshot: return "camera"
        case .voice: return "mic"
        case .link: return "link"
        case .file: return "doc"
        }
    }
    
    // 来源图标
    private var sourceIcon: String {
        switch entry.source {
        case .manual: return "hand.raised"
        case .camera: return "camera"
        case .share: return "square.and.arrow.up"
        case .clipboard: return "clipboard"
        }
    }
    
    // 状态图标
    private var statusIcon: String {
        switch entry.status {
        case .raw: return "circle.dashed"
        case .reviewed: return "checkmark.circle"
        case .organized: return "folder.fill"
        }
    }
    
    // 状态颜色
    private var statusColor: Color {
        switch entry.status {
        case .raw: return .secondary
        case .reviewed: return .green
        case .organized: return .blue
        }
    }
}

// 流式布局辅助组件（用于标签编辑）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += subview.sizeThatFits(.unspecified).width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRowSubviews: [LayoutSubview] = []
        var currentX: CGFloat = 0
        let maxWidth = proposal.width ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && !currentRowSubviews.isEmpty {
                // 创建新行
                rows.append(Row(subviews: currentRowSubviews, height: currentRowSubviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0))
                currentRowSubviews = []
                currentX = 0
            }
            
            currentRowSubviews.append(subview)
            currentX += size.width + spacing
        }
        
        if !currentRowSubviews.isEmpty {
            rows.append(Row(subviews: currentRowSubviews, height: currentRowSubviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0))
        }
        
        return rows
    }
    
    struct Row {
        let subviews: [LayoutSubview]
        let height: CGFloat
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(entry: Entry(
            id: "20260509-153021-a7b3",
            title: "Swift UI 最佳实践",
            content: "# 标题\n\n这是一段 **粗体** 文本和 `代码` 片段。\n\n[链接](https://example.com)",
            type: .note,
            source: .manual,
            status: .reviewed,
            tags: ["Swift", "iOS", "UI"],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "inbox/20260509-153021-a7b3.md",
            attachmentURLs: []
        ))
    }
}