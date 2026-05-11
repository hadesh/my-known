import Foundation
import Testing
@testable import KnowledgeVaultCore

// MARK: - ConflictResolver Tests

struct ConflictResolverTests {

    @Test
    func testConflictResolverNewerWins() {
        // remote.modifiedAt 较新时返回 .useRemote
        let localDate = Date(timeIntervalSince1970: 1000)
        let remoteDate = Date(timeIntervalSince1970: 2000)

        let localEntry = Entry(
            id: "test-id",
            title: "Local",
            content: "Local content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: localDate,
            updated: localDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let remoteEntry = Entry(
            id: "test-id",
            title: "Remote",
            content: "Remote content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: remoteDate,
            updated: remoteDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let localFile = File(entry: localEntry, modifiedAt: localDate)
        let remoteFile = File(entry: remoteEntry, modifiedAt: remoteDate)

        let resolution = ConflictResolver.resolve(local: localFile, remote: remoteFile)

        // 验证返回 useRemote
        var isUseRemote = false
        switch resolution {
        case .useRemote:
            isUseRemote = true
        default:
            isUseRemote = false
        }
        #expect(isUseRemote == true)
    }

    @Test
    func testConflictResolverLocalWins() {
        // local.modifiedAt 较新时返回 .useLocal
        let localDate = Date(timeIntervalSince1970: 2000)
        let remoteDate = Date(timeIntervalSince1970: 1000)

        let localEntry = Entry(
            id: "test-id",
            title: "Local",
            content: "Local content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: localDate,
            updated: localDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let remoteEntry = Entry(
            id: "test-id",
            title: "Remote",
            content: "Remote content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: remoteDate,
            updated: remoteDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let localFile = File(entry: localEntry, modifiedAt: localDate)
        let remoteFile = File(entry: remoteEntry, modifiedAt: remoteDate)

        let resolution = ConflictResolver.resolve(local: localFile, remote: remoteFile)

        // 验证返回 useLocal
        var isUseLocal = false
        switch resolution {
        case .useLocal:
            isUseLocal = true
        default:
            isUseLocal = false
        }
        #expect(isUseLocal == true)
    }

    @Test
    func testConflictResolverSameTimestampUsesRemote() {
        // 相同时间戳 remote 优先
        let sameDate = Date(timeIntervalSince1970: 1000)

        let localEntry = Entry(
            id: "test-id",
            title: "Local",
            content: "Local content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: sameDate,
            updated: sameDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let remoteEntry = Entry(
            id: "test-id",
            title: "Remote",
            content: "Remote content",
            type: .note,
            source: .manual,
            status: .raw,
            tags: [],
            summary: nil,
            created: sameDate,
            updated: sameDate,
            relativePath: "test.md",
            attachmentURLs: []
        )

        let localFile = File(entry: localEntry, modifiedAt: sameDate)
        let remoteFile = File(entry: remoteEntry, modifiedAt: sameDate)

        let resolution = ConflictResolver.resolve(local: localFile, remote: remoteFile)

        // 相同时间戳时，remote 优先
        var isUseRemote = false
        switch resolution {
        case .useRemote:
            isUseRemote = true
        default:
            isUseRemote = false
        }
        #expect(isUseRemote == true)
    }
}
