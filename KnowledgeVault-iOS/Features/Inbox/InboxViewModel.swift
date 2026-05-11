import SwiftUI
import KnowledgeVaultCore

// Inbox 功能的 ViewModel，使用 @Observable 宏（iOS 17+）
@Observable
final class InboxViewModel {
    // 状态属性
    var entries: [Entry] = []           // 收件箱中的条目列表
    var isLoading: Bool = false         // 是否正在加载
    var error: Error? = nil             // 错误信息
    
    // 文件管理器（通过环境注入）
    private var fileManager: KnowledgeVaultFileManager
    
    // 初始化
    init(fileManager: KnowledgeVaultFileManager) {
        self.fileManager = fileManager
    }
    
    // 加载收件箱中的条目列表
    func loadEntries() async {
        isLoading = true
        error = nil
        
        do {
            entries = try await fileManager.listEntries(in: .inbox)
        } catch {
            self.error = error
            // 加载失败时保持空列表
            entries = []
        }
        
        isLoading = false
    }
    
    // 创建新的条目
    // - Parameters:
    //   - content: 条目内容
    //   - type: 条目类型（note/screenshot/voice/link/file）
    //   - source: 条目来源（manual/camera/share/clipboard）
    // - Throws: 创建失败时抛出错误
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws {
        let newEntry = try await fileManager.createEntry(
            content: content,
            type: type,
            source: source
        )
        
        // 将新条目添加到列表开头
        entries.insert(newEntry, at: 0)
    }
    
    // 删除指定条目
    // - Parameter entry: 要删除的条目
    // - Throws: 删除失败时抛出错误
    func deleteEntry(_ entry: Entry) async throws {
        try await fileManager.deleteEntry(id: entry.id)
        
        // 从列表中移除该条目
        entries.removeAll { $0.id == entry.id }
    }
}