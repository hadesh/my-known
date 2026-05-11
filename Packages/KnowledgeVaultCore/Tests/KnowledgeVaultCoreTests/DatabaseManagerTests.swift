import Foundation
import Testing
import GRDB
@testable import KnowledgeVaultCore

// MARK: - DatabaseManager Tests

struct DatabaseManagerTests {

    private func createTemporaryDBURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dbName = "test_\(UUID().uuidString).db"
        return tempDir.appendingPathComponent(dbName)
    }

    @Test
    func testEntryIDIsTextColumn() async throws {
        // 使用临时文件 DB 验证 schema 中 id TEXT
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)

        // 插入一条 entry
        let entry = Entry(
            id: "test-id-123",
            title: "Test",
            content: "Content",
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
        let fetched = try await dbManager.fetchEntry(id: "test-id-123")

        #expect(fetched != nil)
        #expect(fetched?.id == "test-id-123")
    }

    @Test
    func testFTSInsertAndSearch() async throws {
        // 插入 entry 后 FTS 能搜索到
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)

        let entry = Entry(
            id: "fts-test-id",
            title: "Swift Programming",
            content: "Swift is a powerful programming language",
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

        try await dbManager.insertEntry(entry)

        // 搜索 "Swift"
        let results = try await dbManager.ftsSearch(query: "Swift", limit: 10)

        #expect(results.count == 1)
        #expect(results[0].0.id == "fts-test-id")
    }

    @Test
    func testEmbeddingBlobRoundtrip() async throws {
        // [Float] ↔ Data 编解码往返
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)

        // 先插入 entry
        let entry = Entry(
            id: "embed-test-id",
            title: "Test",
            content: "Content",
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

        // 保存 embedding
        let originalVector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        try await dbManager.saveEmbedding(
            entryID: "embed-test-id",
            provider: "test-provider",
            dimensions: 5,
            vector: originalVector
        )

        // 读取 embedding
        let fetched = try await dbManager.fetchEmbeddings(provider: "test-provider")

        #expect(fetched.count == 1)
        #expect(fetched[0].entryID == "embed-test-id")
        #expect(fetched[0].vector.count == 5)

        // 验证浮点数近似相等
        for i in 0..<5 {
            #expect(abs(fetched[0].vector[i] - originalVector[i]) < 1e-6)
        }
    }

    @Test
    func testDeleteCascadesEmbedding() async throws {
        // 删除 entry 时 embeddings 级联删除
        let dbURL = createTemporaryDBURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let dbManager = try await DatabaseManager(dbURL: dbURL)

        // 插入 entry 和 embedding
        let entry = Entry(
            id: "cascade-test-id",
            title: "Test",
            content: "Content",
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

        try await dbManager.saveEmbedding(
            entryID: "cascade-test-id",
            provider: "test-provider",
            dimensions: 3,
            vector: [0.1, 0.2, 0.3]
        )

        // 验证 embedding 存在
        var embeddings = try await dbManager.fetchEmbeddings(provider: "test-provider")
        #expect(embeddings.count == 1)

        // 删除 entry
        try await dbManager.deleteEntry(id: "cascade-test-id")

        // 验证 embedding 也被级联删除
        embeddings = try await dbManager.fetchEmbeddings(provider: "test-provider")
        #expect(embeddings.count == 0)
    }
}
