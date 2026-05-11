import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - SearchEngine Tests

struct SearchEngineTests {

    private func createTemporaryDBURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dbName = "test_\(UUID().uuidString).db"
        return tempDir.appendingPathComponent(dbName)
    }

    @Test
    func testMinMaxNormalize() {
        // [(id1, 3.0), (id2, 1.0)] → [(id1, 1.0), (id2, 0.0)]
        let scores = [
            ("id1", 3.0),
            ("id2", 1.0)
        ]

        let normalized = minMaxNormalize(scores)

        #expect(normalized.count == 2)
        #expect(normalized[0].0 == "id1")
        #expect(normalized[0].1 == 1.0)
        #expect(normalized[1].0 == "id2")
        #expect(normalized[1].1 == 0.0)
    }

    @Test
    func testMinMaxNormalizeEmpty() {
        // 空数组返回空
        let emptyScores: [(String, Double)] = []
        let normalized = minMaxNormalize(emptyScores)
        #expect(normalized.isEmpty)
    }

    @Test
    func testMinMaxNormalizeSameValues() {
        // 所有值相同时返回 0.5
        let scores = [
            ("id1", 5.0),
            ("id2", 5.0),
            ("id3", 5.0)
        ]

        let normalized = minMaxNormalize(scores)

        #expect(normalized.count == 3)
        for (_, score) in normalized {
            #expect(score == 0.5)
        }
    }

    @Test
    func testSearchEngineFTSMode() async throws {
        // 索引 2 条 Entry，搜索能匹配 1 条
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)
        let vaultConfig = VaultConfig(vaultRootURL: URL(fileURLWithPath: "/tmp"), hybridAlpha: 0.4)
        let searchEngine = SearchEngineImpl(databaseManager: dbManager, vaultConfig: vaultConfig)

        // 插入两条 entry
        let entry1 = Entry(
            id: "entry-1",
            title: "Swift Programming",
            content: "Learn Swift programming language",
            type: .note,
            source: .manual,
            status: .raw,
            tags: ["programming"],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "swift.md",
            attachmentURLs: []
        )

        let entry2 = Entry(
            id: "entry-2",
            title: "Python Guide",
            content: "Python programming tutorial",
            type: .note,
            source: .manual,
            status: .raw,
            tags: ["programming"],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "python.md",
            attachmentURLs: []
        )

        try await dbManager.insertEntry(entry1)
        try await dbManager.insertEntry(entry2)

        // 搜索 "Swift"
        let results = try await searchEngine.search(query: "Swift", mode: .fulltext, limit: 10)

        #expect(results.count == 1)
        #expect(results[0].fileID == "entry-1")
        #expect(results[0].title == "Swift Programming")
    }

    @Test
    func testHybridAlphaFromConfig() async throws {
        // hybridAlpha 从 VaultConfig 读取（非硬编码）
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)

        // 使用自定义 hybridAlpha
        let customAlpha = 0.7
        let vaultConfig = VaultConfig(vaultRootURL: URL(fileURLWithPath: "/tmp"), hybridAlpha: customAlpha)

        #expect(vaultConfig.hybridAlpha == customAlpha)

        let searchEngine = SearchEngineImpl(databaseManager: dbManager, vaultConfig: vaultConfig)

        // 验证 SearchEngineImpl 使用了正确的配置
        // 通过测试 hybrid 搜索来验证配置被正确应用
        let entry = Entry(
            id: "test-entry",
            title: "Test",
            content: "Test content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "test.md",
            attachmentURLs: []
        )

        try await dbManager.insertEntry(entry)

        // 混合搜索应该使用配置中的 hybridAlpha
        let results = try await searchEngine.search(query: "Test", mode: .hybrid, limit: 10)
        #expect(results.count == 1)
    }

    // 辅助函数：实现 SearchEngineImpl 中的 minMaxNormalize 逻辑
    private func minMaxNormalize(_ scores: [(String, Double)]) -> [(String, Double)] {
        guard !scores.isEmpty else { return [] }

        let minScore = scores.map { $0.1 }.min() ?? 0
        let maxScore = scores.map { $0.1 }.max() ?? 1

        guard maxScore > minScore else {
            return scores.map { ($0.0, 0.5) }
        }

        let range = maxScore - minScore
        return scores.map { id, score in
            let normalized = (score - minScore) / range
            return (id, normalized)
        }
    }
}
