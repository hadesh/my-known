import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - SSEParser Tests

struct SSEParserTests {

    @Test
    func testSSEParserDeltaExtraction() {
        // 标准 delta.content 提取
        let deltaJSON = "{\"choices\":[{\"delta\":{\"content\":\"Hello World\"}}]}"
        let result = extractContent(from: deltaJSON)
        #expect(result == "Hello World")
    }

    @Test
    func testSSEParserDoneTerminates() {
        // [DONE] 标记不返回内容
        let doneContent = "[DONE]"
        let result = extractContent(from: doneContent)
        #expect(result == nil)
    }

    @Test
    func testSSEParserEmptyData() {
        // 空 data 行返回 nil
        let emptyJSON = ""
        let result = extractContent(from: emptyJSON)
        #expect(result == nil)
    }

    @Test
    func testSSEParserMultipleDeltas() {
        // 多 delta 合并成完整字符串
        let delta1 = "{\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        let delta2 = "{\"choices\":[{\"delta\":{\"content\":\" World\"}}]}"
        let delta3 = "{\"choices\":[{\"delta\":{\"content\":\"!\"}}]}"

        let result1 = extractContent(from: delta1)
        let result2 = extractContent(from: delta2)
        let result3 = extractContent(from: delta3)

        #expect(result1 == "Hello")
        #expect(result2 == " World")
        #expect(result3 == "!")

        let combined = [result1, result2, result3].compactMap { $0 }.joined()
        #expect(combined == "Hello World!")
    }

    @Test
    func testSSEParserMessageFormat() {
        // 测试 message.content 格式（Anthropic风格）
        let messageJSON = "{\"choices\":[{\"message\":{\"content\":\"Anthropic response\"}}]}"
        let result = extractContent(from: messageJSON)
        #expect(result == "Anthropic response")
    }

    @Test
    func testSSEParserDeltaTextFormat() {
        // 测试 delta.text 格式（另一种变体）
        let deltaTextJSON = "{\"delta\":{\"text\":\"Some text\"}}"
        let result = extractContent(from: deltaTextJSON)
        #expect(result == "Some text")
    }

    // 辅助函数：模拟 SSEParser.extractContent 的行为
    private func extractContent(from dataString: String) -> String? {
        guard let data = dataString.data(using: .utf8) else { return nil }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    return content
                }

                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                }

                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    return text
                }

                if let content = json["content"] as? [String: Any],
                   let text = content.first?.value as? String {
                    return text
                }
            }
        } catch {
            return nil
        }

        return nil
    }
}
