import Foundation

public protocol KnowledgeVaultFileManager {
    var vaultURL: URL { get }
    
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry
    func readEntry(id: String) async throws -> Entry
    func updateEntry(id: String, content: String, tags: [String]) async throws
    func moveEntry(id: String, toTopic: String) async throws
    func listEntries(in directory: VaultDirectory) async throws -> [Entry]
    func search(query: String, mode: SearchMode) async throws -> [SearchResult]
    func deleteEntry(id: String) async throws
    func exportEntry(id: String) async throws -> URL
}

public enum VaultDirectory {
    case inbox
    case topics(String)
    case archive
}
