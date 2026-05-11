import Foundation

public struct Entry: Identifiable, Codable, Hashable {
    public let id: String                   // "20260509-153021-a7b3"
    public var title: String?
    public var content: String
    public let type: EntryType
    public let source: EntrySource
    public var status: EntryStatus
    public var tags: [String]
    public var summary: String?
    public let created: Date
    public var updated: Date
    public var relativePath: String
    public var attachmentURLs: [URL]

    public init(
        id: String,
        title: String? = nil,
        content: String,
        type: EntryType,
        source: EntrySource,
        status: EntryStatus,
        tags: [String] = [],
        summary: String? = nil,
        created: Date,
        updated: Date,
        relativePath: String,
        attachmentURLs: [URL] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.type = type
        self.source = source
        self.status = status
        self.tags = tags
        self.summary = summary
        self.created = created
        self.updated = updated
        self.relativePath = relativePath
        self.attachmentURLs = attachmentURLs
    }
}

public enum EntryType: String, Codable {
    case note, screenshot, voice, link, file
}

public enum EntrySource: String, Codable {
    case manual, camera, share, clipboard
}

public enum EntryStatus: String, Codable {
    case raw, reviewed, organized
}