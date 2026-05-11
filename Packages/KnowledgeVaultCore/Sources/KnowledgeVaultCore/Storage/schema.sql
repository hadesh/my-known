-- KnowledgeVault Database Schema
-- SQLite with GRDB.swift
-- FTS5 enabled for full-text search

-- 主表：entries (知识条目)
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

-- 向量表：embeddings (嵌入向量存储)
CREATE TABLE IF NOT EXISTS embeddings (
    entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    dimensions INTEGER NOT NULL,
    vector BLOB NOT NULL,
    PRIMARY KEY (entry_id, provider)
);

-- FTS5 虚拟表：全文搜索
CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
    title, content,
    content='entries',
    content_rowid='rowid',
    tokenize='unicode61'
);

-- 触发器：INSERT 时同步到 FTS
CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
    INSERT INTO entries_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
END;

-- 触发器：UPDATE 时同步到 FTS
CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
    INSERT INTO entries_fts(entries_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
    INSERT INTO entries_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
END;

-- 触发器：DELETE 时同步到 FTS
CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
    INSERT INTO entries_fts(entries_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
END;
