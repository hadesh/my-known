import Foundation

// MARK: - SearchEngineImpl

public actor SearchEngineImpl: SearchEngine {
    private let databaseManager: DatabaseManager
    private let vaultConfig: VaultConfig
    
    public init(databaseManager: DatabaseManager, vaultConfig: VaultConfig) {
        self.databaseManager = databaseManager
        self.vaultConfig = vaultConfig
    }
    
    // MARK: - SearchEngine Protocol
    
    public func indexFile(_ file: MarkdownFile) async throws {
        // Phase 1: 索引操作由 DatabaseManager 自动处理
        // FTS 索引通过 triggers 在 entry 插入/更新时自动维护
    }
    
    public func updateIndex(fileID: String) async throws {
        // Phase 1: 索引更新由 DatabaseManager 自动处理
        // FTS 索引通过 triggers 自动维护
    }
    
    public func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult] {
        switch mode {
        case .fulltext:
            return try await performFulltextSearch(query: query, limit: limit)
        case .hybrid:
            return try await performHybridSearch(query: query, limit: limit)
        case .semantic:
            throw SearchError.notImplemented
        }
    }
    
    public func rebuildIndex() async throws {
        // FTS 索引重建逻辑
        throw SearchError.notImplemented
    }
    
    // MARK: - Private Search Methods
    
    private func performFulltextSearch(query: String, limit: Int) async throws -> [SearchResult] {
        let results = try await databaseManager.ftsSearch(query: query, limit: limit)
        
        return results.map { entry, score in
            SearchResult(
                fileID: entry.id,
                title: entry.title,
                snippet: createSnippet(from: entry.content),
                score: score,
                searchMode: .fulltext,
                tags: entry.tags,
                created: entry.created
            )
        }
    }
    
    private func performHybridSearch(query: String, limit: Int) async throws -> [SearchResult] {
        let ftsResults = try await databaseManager.ftsSearch(query: query, limit: limit * 2)
        
        // Phase 1: 语义搜索结果为空
        let semanticResults: [(String, Double)] = []
        
        // 归一化并合并结果
        return try await mergeResults(
            ftsResults: ftsResults,
            semanticResults: semanticResults,
            limit: limit
        )
    }
    
    private func mergeResults(
        ftsResults: [(Entry, Double)],
        semanticResults: [(String, Double)],
        limit: Int
    ) async throws -> [SearchResult] {
        // 从 VaultConfig 读取混合权重
        let hybridAlpha = vaultConfig.hybridAlpha
        let semanticWeight = 1.0 - hybridAlpha
        
        // 准备 FTS 分数进行归一化
        let ftsScores: [(String, Double)] = ftsResults.map { entry, score in
            // BM25 分数为负值，取绝对值
            (entry.id, abs(score))
        }
        
        // Min-Max 归一化 FTS 分数
        let normalizedFTSScores = minMaxNormalize(ftsScores)
        
        // 构建最终分数映射
        var finalScores: [String: Double] = [:]
        var entryMap: [String: Entry] = [:]
        
        // 处理 FTS 结果
        for (entry, _) in ftsResults {
            entryMap[entry.id] = entry
        }
        
        // 计算混合分数
        for (entryID, normalizedScore) in normalizedFTSScores {
            let hybridScore = normalizedScore * hybridAlpha
            finalScores[entryID] = hybridScore
        }
        
        // Phase 1: 语义搜索结果为空，无需处理 semanticResults
        // Phase 2: 语义分数 × semanticWeight 后叠加
        
        // 按分数排序并构建结果
        let sortedResults = finalScores
            .sorted { $0.value > $1.value }
            .prefix(limit)
        
        return sortedResults.compactMap { entryID, score in
            guard let entry = entryMap[entryID] else { return nil }
            return SearchResult(
                fileID: entry.id,
                title: entry.title,
                snippet: createSnippet(from: entry.content),
                score: score,
                searchMode: .hybrid,
                tags: entry.tags,
                created: entry.created
            )
        }
    }
    
    // MARK: - Normalization
    
    /// 对分数进行 Min-Max 归一化
    /// 将所有分数映射到 [0, 1] 区间
    private func minMaxNormalize(_ scores: [(String, Double)]) -> [(String, Double)] {
        guard !scores.isEmpty else { return [] }
        
        let minScore = scores.map { $0.1 }.min() ?? 0
        let maxScore = scores.map { $0.1 }.max() ?? 1
        
        guard maxScore > minScore else {
            // 如果所有分数相同，返回均等分数 0.5
            return scores.map { ($0.0, 0.5) }
        }
        
        let range = maxScore - minScore
        return scores.map { id, score in
            let normalized = (score - minScore) / range
            return (id, normalized)
        }
    }
    
    // MARK: - Helpers
    
    private func createSnippet(from content: String) -> String {
        let maxLength = 200
        if content.count <= maxLength {
            return content
        }
        let endIndex = content.index(content.startIndex, offsetBy: maxLength)
        return String(content[..<endIndex]) + "..."
    }
}
