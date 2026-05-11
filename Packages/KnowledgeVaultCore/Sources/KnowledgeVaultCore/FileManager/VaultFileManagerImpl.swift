import Foundation

public actor VaultFileManagerImpl: KnowledgeVaultFileManager {
    public let vaultURL: URL
    private let fileManager = FileManager.default
    
    public init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }
    
    private func ensureDirectoryExists(at url: URL) throws {
        var coordinatorError: NSError?
        var setupError: Error?
        
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                if !self.fileManager.fileExists(atPath: coordinatedURL.path) {
                    try self.fileManager.createDirectory(at: coordinatedURL, withIntermediateDirectories: true, attributes: nil)
                }
            } catch {
                setupError = error
            }
        }
        
        if let error = setupError {
            throw error
        }
        if let error = coordinatorError {
            throw error
        }
    }
    
    private func setupIndexDirectory() throws {
        let indexURL = vaultURL.appendingPathComponent(".index", isDirectory: true)
        
        try ensureDirectoryExists(at: indexURL)
        
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        
        var coordinatorError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: indexURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                try (coordinatedURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            } catch {
            }
        }
    }
    
    private func directoryURL(for vaultDirectory: VaultDirectory) -> URL {
        switch vaultDirectory {
        case .inbox:
            return vaultURL.appendingPathComponent("inbox", isDirectory: true)
        case .topics(let topic):
            return vaultURL.appendingPathComponent("topics", isDirectory: true)
                .appendingPathComponent(topic, isDirectory: true)
        case .archive:
            return vaultURL.appendingPathComponent("archive", isDirectory: true)
        }
    }
    
    public func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let uuidPrefix = UUID().uuidString.prefix(4).lowercased()
        let entryID = "\(dateString)-\(uuidPrefix)"
        
        let inboxURL = directoryURL(for: .inbox)
        try ensureDirectoryExists(at: inboxURL)
        try setupIndexDirectory()
        
        var entry = Entry(
            id: entryID,
            title: nil,
            content: content,
            type: type,
            source: source,
            status: .raw,
            tags: [],
            summary: nil,
            created: Date(),
            updated: Date(),
            relativePath: "inbox/\(entryID).md",
            attachmentURLs: []
        )
        
        let markdownContent = MarkdownSerializer.entryToMarkdown(entry)
        
        let fileURL = inboxURL.appendingPathComponent("\(entryID).md")
        
        var coordinatorError: NSError?
        var writeError: Error?
        
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                try markdownContent.write(to: coordinatedURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }
        
        if let error = writeError {
            throw error
        }
        if let error = coordinatorError {
            throw error
        }
        
        return entry
    }
    
    public func readEntry(id: String) async throws -> Entry {
        let directories: [VaultDirectory] = [.inbox, .archive] + getAllTopicDirectories()
        
        for directory in directories {
            let dirURL = directoryURL(for: directory)
            let fileURL = dirURL.appendingPathComponent("\(id).md")
            
            var coordinatorError: NSError?
            var entry: Entry?
            
            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
                do {
                    if self.fileManager.fileExists(atPath: coordinatedURL.path) {
                        let content = try String(contentsOf: coordinatedURL, encoding: .utf8)
                        entry = MarkdownSerializer.markdownToEntry(content)
                    }
                } catch {
                }
            }
            
            if let foundEntry = entry {
                return foundEntry
            }
        }
        
        throw VaultFileManagerError.entryNotFound(id: id)
    }
    
    public func updateEntry(id: String, content: String, tags: [String]) async throws {
        let entry = try await readEntry(id: id)
        
        var updatedEntry = entry
        updatedEntry.content = content
        updatedEntry.tags = tags
        updatedEntry.updated = Date()
        
        let markdownContent = MarkdownSerializer.entryToMarkdown(updatedEntry)
        
        let directories: [VaultDirectory] = [.inbox, .archive] + getAllTopicDirectories()
        
        for directory in directories {
            let dirURL = directoryURL(for: directory)
            let fileURL = dirURL.appendingPathComponent("\(id).md")
            
            var coordinatorError: NSError?
            var found = false
            
            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
                if self.fileManager.fileExists(atPath: coordinatedURL.path) {
                    found = true
                }
            }
            
            if found {
                var writeError: Error?
                NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
                    do {
                        try markdownContent.write(to: coordinatedURL, atomically: true, encoding: .utf8)
                    } catch {
                        writeError = error
                    }
                }
                
                if let error = writeError {
                    throw error
                }
                return
            }
        }
        
        throw VaultFileManagerError.entryNotFound(id: id)
    }
    
    public func moveEntry(id: String, toTopic: String) async throws {
        let directories: [VaultDirectory] = [.inbox, .archive] + getAllTopicDirectories()
        var sourceURL: URL?
        
        for directory in directories {
            let dirURL = directoryURL(for: directory)
            let fileURL = dirURL.appendingPathComponent("\(id).md")
            
            var coordinatorError: NSError?
            var exists = false
            
            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { coordinatedURL in
                exists = self.fileManager.fileExists(atPath: coordinatedURL.path)
            }
            
            if exists {
                sourceURL = fileURL
                break
            }
        }
        
        guard let sourceFileURL = sourceURL else {
            throw VaultFileManagerError.entryNotFound(id: id)
        }
        
        let targetDirectory = VaultDirectory.topics(toTopic)
        let targetDirURL = directoryURL(for: targetDirectory)
        try ensureDirectoryExists(at: targetDirURL)
        
        let targetFileURL = targetDirURL.appendingPathComponent("\(id).md")
        
        var coordinatorError: NSError?
        var moveError: Error?
        
        NSFileCoordinator().coordinate(writingItemAt: sourceFileURL, options: .forMoving, writingItemAt: targetFileURL, options: .forReplacing, error: &coordinatorError) { source, target in
            do {
                try self.fileManager.moveItem(at: source, to: target)
            } catch {
                moveError = error
            }
        }
        
        if let error = moveError {
            throw error
        }
        if let error = coordinatorError {
            throw error
        }
    }
    
    public func listEntries(in directory: VaultDirectory) async throws -> [Entry] {
        let dirURL = directoryURL(for: directory)
        
        if case .topics = directory {
            try ensureDirectoryExists(at: dirURL)
        }
        
        var coordinatorError: NSError?
        var entries: [Entry] = []
        var readError: Error?
        
        NSFileCoordinator().coordinate(readingItemAt: dirURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(
                    at: coordinatedURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                
                for fileURL in fileURLs where fileURL.pathExtension == "md" {
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        if let entry = MarkdownSerializer.markdownToEntry(content) {
                            entries.append(entry)
                        }
                    } catch {
                    }
                }
            } catch {
                readError = error
            }
        }
        
        if let error = readError {
            throw error
        }
        if let error = coordinatorError {
            throw error
        }
        
        return entries.sorted { $0.created > $1.created }
    }
    
    public func search(query: String, mode: SearchMode) async throws -> [SearchResult] {
        var allEntries: [Entry] = []
        
        let inboxEntries = try await listEntries(in: .inbox)
        allEntries.append(contentsOf: inboxEntries)
        
        let archiveEntries = try await listEntries(in: .archive)
        allEntries.append(contentsOf: archiveEntries)
        
        let topics = getAllTopicNames()
        for topic in topics {
            let topicEntries = try await listEntries(in: .topics(topic))
            allEntries.append(contentsOf: topicEntries)
        }
        
        let lowercasedQuery = query.lowercased()
        var results: [SearchResult] = []
        
        for entry in allEntries {
            let contentLower = entry.content.lowercased()
            let tagsLower = entry.tags.map { $0.lowercased() }
            let titleLower = entry.title?.lowercased() ?? ""
            
            var score: Double = 0
            var snippet = entry.content.prefix(200).description
            
            if titleLower.contains(lowercasedQuery) {
                score += 2.0
            }
            
            if contentLower.contains(lowercasedQuery) {
                score += 1.0
                if let range = contentLower.range(of: lowercasedQuery) {
                    let start = contentLower.index(range.lowerBound, offsetBy: -50, limitedBy: contentLower.startIndex) ?? contentLower.startIndex
                    let end = contentLower.index(range.upperBound, offsetBy: 50, limitedBy: contentLower.endIndex) ?? contentLower.endIndex
                    snippet = String(entry.content[start..<end])
                }
            }
            
            if tagsLower.contains(where: { $0.contains(lowercasedQuery) }) {
                score += 1.5
            }
            
            if score > 0 {
                results.append(SearchResult(
                    fileID: entry.id,
                    title: entry.title,
                    snippet: snippet,
                    score: score,
                    searchMode: mode,
                    tags: entry.tags,
                    created: entry.created
                ))
            }
        }
        
        return results.sorted { $0.score > $1.score }
    }
    
    public func deleteEntry(id: String) async throws {
        let directories: [VaultDirectory] = [.inbox, .archive] + getAllTopicDirectories()
        
        for directory in directories {
            let dirURL = directoryURL(for: directory)
            let fileURL = dirURL.appendingPathComponent("\(id).md")
            
            var coordinatorError: NSError?
            var deleteError: Error?
            var found = false
            
            NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { coordinatedURL in
                do {
                    if self.fileManager.fileExists(atPath: coordinatedURL.path) {
                        try self.fileManager.removeItem(at: coordinatedURL)
                        found = true
                    }
                } catch {
                    deleteError = error
                }
            }
            
            if found {
                if let error = deleteError {
                    throw error
                }
                return
            }
        }
        
        throw VaultFileManagerError.entryNotFound(id: id)
    }
    
    public func exportEntry(id: String) async throws -> URL {
        let entry = try await readEntry(id: id)
        
        let tempDir = fileManager.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("\(entry.id).md")
        
        let markdownContent = MarkdownSerializer.entryToMarkdown(entry)
        
        var coordinatorError: NSError?
        var writeError: Error?
        
        NSFileCoordinator().coordinate(writingItemAt: exportURL, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                try markdownContent.write(to: coordinatedURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }
        
        if let error = writeError {
            throw error
        }
        if let error = coordinatorError {
            throw error
        }
        
        return exportURL
    }
    
    private func getAllTopicNames() -> [String] {
        let topicsURL = vaultURL.appendingPathComponent("topics", isDirectory: true)
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: topicsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return contents.compactMap { url -> String? in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    return url.lastPathComponent
                }
                return nil
            }
        } catch {
            return []
        }
    }
    
    private func getAllTopicDirectories() -> [VaultDirectory] {
        return getAllTopicNames().map { .topics($0) }
    }
}

public enum VaultFileManagerError: Error {
    case entryNotFound(id: String)
    case invalidEntryData
    case directoryCreationFailed
    case fileWriteFailed
    case fileReadFailed
}
