import Foundation

// MARK: - SearchError

public enum SearchError: Error {
    case notImplemented
    case databaseError(String)
    case invalidQuery
    case indexRebuildFailed
}

// MARK: - MarkdownFile

public struct MarkdownFile {
    public let id: String
    public let title: String?
    public let content: String
    public let tags: [String]
    
    public init(id: String, title: String?, content: String, tags: [String]) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
    }
}

// MARK: - SearchEngine Protocol

public protocol SearchEngine {
    /// 将 MarkdownFile 索引到搜索系统
    func indexFile(_ file: MarkdownFile) async throws
    
    /// 更新指定 fileID 的索引
    func updateIndex(fileID: String) async throws
    
    /// 执行搜索
    /// - Parameters:
    ///   - query: 搜索查询字符串
    ///   - mode: 搜索模式（全文、语义、混合）
    ///   - limit: 返回结果数量限制
    /// - Returns: 搜索结果数组
    func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult]
    
    /// 重建整个搜索索引
    func rebuildIndex() async throws
}
