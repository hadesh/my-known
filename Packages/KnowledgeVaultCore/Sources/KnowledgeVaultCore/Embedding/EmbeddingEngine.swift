import Foundation
import Accelerate

// MARK: - 错误类型

public enum EmbeddingError: Error {
    case notImplementedInPhase1
    case notImplemented
    case dimensionMismatch
    case emptyVector
    case invalidFileID
    case embeddingGenerationFailed(String)
}

// MARK: - 文件相似度结果

public struct FileSimilarity: Identifiable, Equatable {
    public let fileID: String
    public let score: Float

    public var id: String { fileID }

    public init(fileID: String, score: Float) {
        self.fileID = fileID
        self.score = score
    }
}

// MARK: - 内部索引类型

typealias EmbeddingIndex = [String: [Float]]

// MARK: - Embedding Engine

public actor EmbeddingEngine {
    // MARK: - Properties

    private var index: EmbeddingIndex = [:]
    private let embeddingDimension: Int = 768 // 标准BERT维度，可配置

    // MARK: - Initialization

    public init() {}

    // MARK: - 余弦相似度计算 (Accelerate框架)

    /// 使用Accelerate框架计算两个向量的余弦相似度
    /// 公式: cosine_similarity = (a · b) / (||a|| * ||b||)
    public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        // 维度检查
        guard a.count == b.count, !a.isEmpty else {
            return 0.0
        }

        let count = vDSP_Length(a.count)

        // 使用 vDSP_dotpr 计算点积 (a · b)
        var dotProduct: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, count)

        // 使用 vDSP_svesq 计算向量模的平方 (||a||²)
        var normASquared: Float = 0.0
        vDSP_svesq(a, 1, &normASquared, count)

        // 使用 vDSP_svesq 计算向量模的平方 (||b||²)
        var normBSquared: Float = 0.0
        vDSP_svesq(b, 1, &normBSquared, count)

        // 计算余弦相似度
        let normA = sqrt(normASquared)
        let normB = sqrt(normBSquared)

        // 避免除以零
        if normA == 0 || normB == 0 {
            return 0.0
        }

        return dotProduct / (normA * normB)
    }

    /// 批量计算余弦相似度，返回排序后的结果
    public func rankBySimilarity(
        query: [Float],
        candidates: [(fileID: String, embedding: [Float])]
    ) -> [(String, Float)] {
        // 计算每个候选的相似度
        let scoredCandidates = candidates.compactMap { (fileID, embedding) -> (String, Float)? in
            guard embedding.count == query.count else { return nil }
            let score = cosineSimilarity(query, embedding)
            return (fileID, score)
        }

        // 按相似度降序排序
        return scoredCandidates.sorted { $0.1 > $1.1 }
    }

    // MARK: - Embedding 生成 (Phase 1: 骨架)

    /// 为单个文件生成embedding
    /// Phase 1: 抛出 notImplementedInPhase1
    public func generateEmbedding(for fileID: String) async throws {
        guard !fileID.isEmpty else {
            throw EmbeddingError.invalidFileID
        }
        throw EmbeddingError.notImplementedInPhase1
    }

    /// 批量生成embedding
    /// Phase 1: 抛出 notImplementedInPhase1
    public func batchGenerate(for fileIDs: [String]) async throws {
        guard !fileIDs.isEmpty else {
            return
        }
        throw EmbeddingError.notImplementedInPhase1
    }

    // MARK: - 语义搜索 (Phase 1: 骨架)

    /// 语义搜索：根据查询文本返回最相似的文件
    /// Phase 1: 抛出 notImplemented
    public func semanticSearch(query: String, topK: Int) async throws -> [FileSimilarity] {
        guard !query.isEmpty, topK > 0 else {
            return []
        }
        throw EmbeddingError.notImplemented
    }

    // MARK: - 索引管理

    /// 检查文件是否需要更新embedding
    public func needsUpdate(fileID: String) async -> Bool {
        // Phase 1: 简单检查是否存在于索引中
        // 实际实现会检查文件内容哈希或修改时间
        return index[fileID] == nil
    }

    /// 增量更新索引
    /// Phase 1: 抛出 notImplementedInPhase1
    public func incrementalUpdate() async throws {
        throw EmbeddingError.notImplementedInPhase1
    }

    // MARK: - 内部方法 (Phase 2+)

    /// 将 [Float] 转换为 Data (用于SQLite BLOB存储)
    /// 使用 withUnsafeBytes 模式
    private func embeddingToData(_ embedding: [Float]) -> Data {
        return embedding.withUnsafeBytes { buffer in
            Data(buffer)
        }
    }

    /// 将 Data 转换为 [Float] (从SQLite BLOB读取)
    private func dataToEmbedding(_ data: Data) -> [Float] {
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { buffer -> [Float] in
            guard let baseAddress = buffer.baseAddress else { return [] }
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            return (0..<floatCount).map { floatBuffer[$0] }
        }
    }

    /// 获取embedding维度
    public var dimension: Int {
        get async {
            return embeddingDimension
        }
    }
}
