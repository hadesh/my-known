import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - PromptBuilder Tests

struct PromptBuilderTests {

    @Test
    func testEstimateTokensBasic() {
        // "Hello World" → 2（11 / 4 取整）
        let text = "Hello World"
        let expectedTokens = text.count / 4

        let estimated = PromptBuilder.estimateTokens(text)

        #expect(estimated == expectedTokens)
        #expect(estimated == 2)
    }

    @Test
    func testEstimateTokensEmptyString() {
        // 空字符串应该返回 0
        let text = ""
        let estimated = PromptBuilder.estimateTokens(text)

        #expect(estimated == 0)
    }

    @Test
    func testEstimateTokensLongText() {
        // 长文本 token 估算
        let text = "This is a longer text with multiple words to test token estimation."
        let expectedTokens = text.count / 4

        let estimated = PromptBuilder.estimateTokens(text)

        #expect(estimated == expectedTokens)
    }

    @Test
    func testPromptBuilderTokenTruncation() {
        // 超出预算时 contexts 数量减少
        let snippets = [
            ContextSnippet(fileID: "1", title: "Snippet 1", path: "/1.md", content: String(repeating: "A", count: 400)),
            ContextSnippet(fileID: "2", title: "Snippet 2", path: "/2.md", content: String(repeating: "B", count: 400)),
            ContextSnippet(fileID: "3", title: "Snippet 3", path: "/3.md", content: String(repeating: "C", count: 400))
        ]

        // 估算每个 snippet 的 token
        let tokensPerSnippet = PromptBuilder.estimateTokens(snippets[0].content)

        // 设置较小的预算，使得只能容纳 1-2 个 snippet
        let maxTokens = tokensPerSnippet + 100

        let truncated = PromptBuilder.truncateContexts(snippets, maxTokens: maxTokens)

        // 验证 contexts 被截断
        #expect(truncated.count < snippets.count)
    }

    @Test
    func testPromptBuilderTokenTruncationWithinBudget() {
        // 在预算范围内，contexts 应该完整保留
        let snippets = [
            ContextSnippet(fileID: "1", title: "Snippet 1", path: "/1.md", content: "Short content"),
            ContextSnippet(fileID: "2", title: "Snippet 2", path: "/2.md", content: "Another short")
        ]

        let totalTokens = snippets.map { PromptBuilder.estimateTokens($0.content) }.reduce(0, +)
        let maxTokens = totalTokens + 100

        let truncated = PromptBuilder.truncateContexts(snippets, maxTokens: maxTokens)

        // 在预算范围内，应该保留所有 contexts
        #expect(truncated.count == snippets.count)
    }

    @Test
    func testBuildSystemPromptNotEmpty() {
        // buildSystemPrompt 返回非空字符串
        let contexts: [ContextSnippet] = []
        let prompt = PromptBuilder.buildSystemPrompt(contexts: contexts)

        #expect(!prompt.isEmpty)
        #expect(prompt.contains("helpful assistant"))
    }

    @Test
    func testBuildSystemPromptWithContexts() {
        // 带 contexts 的 system prompt
        let snippets = [
            ContextSnippet(fileID: "1", title: "Test Doc", path: "/test.md", content: "This is test content.")
        ]

        let prompt = PromptBuilder.buildSystemPrompt(contexts: snippets)

        #expect(!prompt.isEmpty)
        #expect(prompt.contains("Test Doc"))
        #expect(prompt.contains("This is test content"))
    }

    @Test
    func testBuildSystemPromptMultipleContexts() {
        // 多个 contexts 的 system prompt
        let snippets = [
            ContextSnippet(fileID: "1", title: "Doc 1", path: "/1.md", content: "Content 1"),
            ContextSnippet(fileID: "2", title: "Doc 2", path: "/2.md", content: "Content 2")
        ]

        let prompt = PromptBuilder.buildSystemPrompt(contexts: snippets)

        #expect(!prompt.isEmpty)
        #expect(prompt.contains("Source 1"))
        #expect(prompt.contains("Source 2"))
    }
}
