import Foundation

public struct SearchResult: Identifiable {
    public let fileID: String
    public var id: String { fileID }   // 满足 Identifiable
    public let title: String?
    public let snippet: String
    public let score: Double
    public let searchMode: SearchMode
    public let tags: [String]
    public let created: Date

    public init(
        fileID: String,
        title: String? = nil,
        snippet: String,
        score: Double,
        searchMode: SearchMode,
        tags: [String] = [],
        created: Date
    ) {
        self.fileID = fileID
        self.title = title
        self.snippet = snippet
        self.score = score
        self.searchMode = searchMode
        self.tags = tags
        self.created = created
    }
}

public enum SearchMode: String, Codable {
    case fulltext, semantic, hybrid
}