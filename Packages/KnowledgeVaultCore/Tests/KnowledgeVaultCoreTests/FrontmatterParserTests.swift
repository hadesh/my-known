import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - FrontmatterParser Tests

struct FrontmatterParserTests {

    @Test
    func testFrontmatterParseTitleAndTags() {
        // 解析含 title: 和 tags: 的标准 frontmatter
        let markdown = """
        ---
        title: "Test Entry"
        tags:
          - swift
          - testing
        ---
        This is the body content.
        """

        let result = FrontmatterParser.parse(markdown)

        #expect(result.frontmatter != nil)
        #expect(result.frontmatter?.title == "Test Entry")
        #expect(result.frontmatter?.tags == ["swift", "testing"])
        #expect(result.body == "This is the body content.")
    }

    @Test
    func testFrontmatterParseEntrySourceAliasMapping() {
        // camera-roll → .camera, share-extension → .share
        let cameraMarkdown = """
        ---
        title: "Photo"
        source: camera-roll
        ---
        Body
        """

        let shareMarkdown = """
        ---
        title: "Link"
        source: share-extension
        ---
        Body
        """

        let cameraResult = FrontmatterParser.parse(cameraMarkdown)
        let shareResult = FrontmatterParser.parse(shareMarkdown)

        #expect(cameraResult.frontmatter?.source == .camera)
        #expect(shareResult.frontmatter?.source == .share)
    }

    @Test
    func testFrontmatterRoundtrip() {
        // parse + serialize 往返一致
        let originalData = FrontmatterData(
            id: "20260509-153021-a7b3",
            title: "Test Entry",
            type: .note,
            source: .manual,
            status: .raw,
            tags: ["swift", "testing"],
            summary: "A test summary",
            created: nil,
            updated: nil,
            relativePath: "test.md",
            attachmentURLs: nil
        )

        let serialized = FrontmatterParser.serialize(data: originalData)
        let (parsedData, _) = FrontmatterParser.parse(serialized)

        #expect(parsedData != nil)
        #expect(parsedData?.id == originalData.id)
        #expect(parsedData?.title == originalData.title)
        #expect(parsedData?.type == originalData.type)
        #expect(parsedData?.source == originalData.source)
        #expect(parsedData?.status == originalData.status)
        #expect(parsedData?.tags == originalData.tags)
        #expect(parsedData?.summary == originalData.summary)
        #expect(parsedData?.relativePath == originalData.relativePath)
    }
}
