import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - CosineSimilarity Tests

struct CosineSimilarityTests {

    @Test
    func testCosineSimilaritySameVector() async {
        // 相同向量 ≈ 1.0（误差 < 1e-6）
        let engine = EmbeddingEngine()
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]

        let similarity = await engine.cosineSimilarity(vector, vector)

        // 相同向量的余弦相似度应该接近 1.0
        #expect(abs(similarity - 1.0) < 1e-6)
    }

    @Test
    func testCosineSimilarityOrthogonal() async {
        // 正交向量 ≈ 0.0（误差 < 1e-6）
        let engine = EmbeddingEngine()
        let vectorA: [Float] = [1.0, 0.0, 0.0]
        let vectorB: [Float] = [0.0, 1.0, 0.0]

        let similarity = await engine.cosineSimilarity(vectorA, vectorB)

        // 正交向量的点积为 0，余弦相似度应该接近 0.0
        #expect(abs(similarity - 0.0) < 1e-6)
    }

    @Test
    func testCosineSimilarityZeroVector() async {
        // 零向量不 crash（返回 0）
        let engine = EmbeddingEngine()
        let vectorA: [Float] = [1.0, 2.0, 3.0]
        let zeroVector: [Float] = [0.0, 0.0, 0.0]

        let similarity = await engine.cosineSimilarity(vectorA, zeroVector)

        // 零向量的模为 0，应该返回 0.0 而不是 crash
        #expect(similarity == 0.0)
    }

    @Test
    func testCosineSimilarityOppositeDirection() async {
        // 相反方向的向量 ≈ -1.0
        let engine = EmbeddingEngine()
        let vectorA: [Float] = [1.0, 2.0, 3.0]
        let vectorB: [Float] = [-1.0, -2.0, -3.0]

        let similarity = await engine.cosineSimilarity(vectorA, vectorB)

        // 相反方向向量的余弦相似度应该接近 -1.0
        #expect(abs(similarity - (-1.0)) < 1e-5)
    }

    @Test
    func testCosineSimilarityDifferentMagnitudes() async {
        // 测试不同模长的同方向向量
        let engine = EmbeddingEngine()
        let vectorA: [Float] = [1.0, 2.0, 3.0]
        let vectorB: [Float] = [2.0, 4.0, 6.0]

        let similarity = await engine.cosineSimilarity(vectorA, vectorB)

        // 同方向向量，余弦相似度应该接近 1.0
        #expect(abs(similarity - 1.0) < 1e-6)
    }

    @Test
    func testCosineSimilarityEmptyVector() async {
        // 空向量测试
        let engine = EmbeddingEngine()
        let emptyVector: [Float] = []
        let nonEmptyVector: [Float] = [1.0, 2.0, 3.0]

        let similarity = await engine.cosineSimilarity(emptyVector, nonEmptyVector)

        // 空向量应该返回 0.0
        #expect(similarity == 0.0)
    }

    @Test
    func testCosineSimilarityDimensionMismatch() async {
        // 维度不匹配测试
        let engine = EmbeddingEngine()
        let vectorA: [Float] = [1.0, 2.0, 3.0]
        let vectorB: [Float] = [1.0, 2.0]

        let similarity = await engine.cosineSimilarity(vectorA, vectorB)

        // 维度不匹配应该返回 0.0
        #expect(similarity == 0.0)
    }
}
