import Foundation
import GRDB

public actor DatabaseManager {
    private let pool: DatabasePool
    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS entries (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'raw',
        tags TEXT NOT NULL DEFAULT '[]',
        summary TEXT,
        created REAL NOT NULL,
        updated REAL NOT NULL,
        relative_path TEXT NOT NULL,
        attachment_urls TEXT NOT NULL DEFAULT '[]'
    );
    CREATE TABLE IF NOT EXISTS embeddings (
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        provider TEXT NOT NULL,
        dimensions INTEGER NOT NULL,
        vector BLOB NOT NULL,
        PRIMARY KEY (entry_id, provider)
    );
    CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
        title, content,
        content='entries',
        content_rowid='rowid',
        tokenize='unicode61'
    );
    CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
        INSERT INTO entries_fts(rowid, title, content)
        VALUES (new.rowid, new.title, new.content);
    END;
    CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
        INSERT INTO entries_fts(entries_fts, rowid, title, content)
        VALUES('delete', old.rowid, old.title, old.content);
        INSERT INTO entries_fts(rowid, title, content)
        VALUES (new.rowid, new.title, new.content);
    END;
    CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
        INSERT INTO entries_fts(entries_fts, rowid, title, content)
        VALUES('delete', old.rowid, old.title, old.content);
    END;
    """
    
    public init(dbURL: URL) async throws {
        var config = Configuration()
        config.maximumReaderCount = 5
        
        self.pool = try DatabasePool(path: dbURL.path, configuration: config)
        try await migrate()
    }
    
    private func migrate() async throws {
        try await pool.write { db in
            try db.execute(sql: DatabaseManager.schemaSQL)
        }
    }
    
    // MARK: - Entry Operations
    
    public func insertEntry(_ entry: Entry) async throws {
        try await pool.write { db in
            let tagsJSON = try JSONEncoder().encode(entry.tags)
            let attachmentURLsJSON = try JSONEncoder().encode(entry.attachmentURLs.map { $0.absoluteString })
            
            try db.execute(
                sql: """
                INSERT INTO entries (
                    id, title, content, type, source, status, tags, summary,
                    created, updated, relative_path, attachment_urls
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    entry.id,
                    entry.title,
                    entry.content,
                    entry.type.rawValue,
                    entry.source.rawValue,
                    entry.status.rawValue,
                    String(data: tagsJSON, encoding: .utf8) ?? "[]",
                    entry.summary,
                    entry.created.timeIntervalSince1970,
                    entry.updated.timeIntervalSince1970,
                    entry.relativePath,
                    String(data: attachmentURLsJSON, encoding: .utf8) ?? "[]"
                ]
            )
        }
    }
    
    public func updateEntry(_ entry: Entry) async throws {
        try await pool.write { db in
            let tagsJSON = try JSONEncoder().encode(entry.tags)
            let attachmentURLsJSON = try JSONEncoder().encode(entry.attachmentURLs.map { $0.absoluteString })
            
            try db.execute(
                sql: """
                UPDATE entries SET
                    title = ?,
                    content = ?,
                    type = ?,
                    source = ?,
                    status = ?,
                    tags = ?,
                    summary = ?,
                    updated = ?,
                    relative_path = ?,
                    attachment_urls = ?
                WHERE id = ?
                """,
                arguments: [
                    entry.title,
                    entry.content,
                    entry.type.rawValue,
                    entry.source.rawValue,
                    entry.status.rawValue,
                    String(data: tagsJSON, encoding: .utf8) ?? "[]",
                    entry.summary,
                    entry.updated.timeIntervalSince1970,
                    entry.relativePath,
                    String(data: attachmentURLsJSON, encoding: .utf8) ?? "[]",
                    entry.id
                ]
            )
        }
    }
    
    public func deleteEntry(id: String) async throws {
        try await pool.write { db in
            try db.execute(sql: "DELETE FROM entries WHERE id = ?", arguments: [id])
        }
    }
    
    public func fetchEntry(id: String) async throws -> Entry? {
        try await pool.read { [self] db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM entries WHERE id = ?", arguments: [id]) else {
                return nil
            }
            return try DatabaseManager.entryFromRow(row)
        }
    }
    
    // MARK: - FTS Search
    
    public func ftsSearch(query: String, limit: Int) async throws -> [(Entry, Double)] {
        try await pool.read { [self] db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT e.*, rank
                FROM entries_fts
                JOIN entries e ON entries_fts.rowid = e.rowid
                WHERE entries_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """,
                arguments: [query, limit]
            )
            
            return rows.compactMap { row in
                guard let entry = try? DatabaseManager.entryFromRow(row) else { return nil }
                let rank = row["rank"] as Double
                let score = abs(rank)
                return (entry, score)
            }
        }
    }
    
    // MARK: - Embedding Operations
    
    public func saveEmbedding(
        entryID: String,
        provider: String,
        dimensions: Int,
        vector: [Float]
    ) async throws {
        let vectorData = DatabaseManager.vectorToData(vector)
        
        try await pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO embeddings (entry_id, provider, dimensions, vector)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(entry_id, provider) DO UPDATE SET
                    dimensions = excluded.dimensions,
                    vector = excluded.vector
                """,
                arguments: [entryID, provider, dimensions, vectorData]
            )
        }
    }
    
    public func fetchEmbeddings(provider: String) async throws -> [(entryID: String, vector: [Float])] {
        try await pool.read { [self] db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT entry_id, vector FROM embeddings WHERE provider = ?",
                arguments: [provider]
            )
            
            return rows.compactMap { row in
                guard let entryID: String = row["entry_id"],
                      let vectorData: Data = row["vector"] else { return nil }
                let vector = DatabaseManager.dataToVector(vectorData)
                return (entryID: entryID, vector: vector)
            }
        }
    }
    
    // MARK: - Helpers
    
    private static func entryFromRow(_ row: Row) throws -> Entry {
        let tagsJSON = row["tags"] as String
        let attachmentURLsJSON = row["attachment_urls"] as String
        
        let tags = try JSONDecoder().decode([String].self, from: tagsJSON.data(using: .utf8) ?? Data())
        let attachmentURLStrings = try JSONDecoder().decode([String].self, from: attachmentURLsJSON.data(using: .utf8) ?? Data())
        let attachmentURLs = attachmentURLStrings.compactMap { URL(string: $0) }
        
        return Entry(
            id: row["id"],
            title: row["title"],
            content: row["content"],
            type: EntryType(rawValue: row["type"])!,
            source: EntrySource(rawValue: row["source"])!,
            status: EntryStatus(rawValue: row["status"])!,
            tags: tags,
            summary: row["summary"],
            created: Date(timeIntervalSince1970: row["created"]),
            updated: Date(timeIntervalSince1970: row["updated"]),
            relativePath: row["relative_path"],
            attachmentURLs: attachmentURLs
        )
    }
    
    private static func vectorToData(_ vector: [Float]) -> Data {
        var data = Data()
        data.reserveCapacity(vector.count * MemoryLayout<Float>.size)
        
        vector.withUnsafeBytes { buffer in
            data.append(contentsOf: buffer)
        }
        
        return data
    }
    
    private static func dataToVector(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var vector = [Float](repeating: 0, count: count)
        
        vector.withUnsafeMutableBytes { buffer in
            _ = data.copyBytes(to: buffer)
        }
        
        return vector
    }
}
