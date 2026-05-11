import Foundation

public enum MarkdownSerializer {
    
    public static func entryToMarkdown(_ entry: Entry) -> String {
        var frontmatterData = FrontmatterData()
        frontmatterData.id = entry.id
        frontmatterData.title = entry.title
        frontmatterData.type = entry.type
        frontmatterData.source = entry.source
        frontmatterData.status = entry.status
        frontmatterData.tags = entry.tags
        frontmatterData.summary = entry.summary
        frontmatterData.created = entry.created
        frontmatterData.updated = entry.updated
        frontmatterData.relativePath = entry.relativePath
        frontmatterData.attachmentURLs = entry.attachmentURLs
        
        let frontmatter = FrontmatterParser.serialize(data: frontmatterData)
        
        var parts: [String] = [frontmatter]
        
        if let title = entry.title, !title.isEmpty {
            parts.append("# \(title)")
        }
        
        parts.append(entry.content)
        
        return parts.joined(separator: "\n\n")
    }
    
    public static func markdownToEntry(_ markdown: String) -> Entry? {
        let (frontmatter, body) = FrontmatterParser.parse(markdown)
        
        guard let data = frontmatter else {
            return nil
        }
        
        guard let id = data.id else {
            return nil
        }
        
        let created = data.created ?? Date()
        let updated = data.updated ?? created
        
        var content = body
        var extractedTitle: String? = data.title
        
        if extractedTitle == nil || extractedTitle?.isEmpty == true {
            if let firstLine = body.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first,
               firstLine.hasPrefix("# ") {
                extractedTitle = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let newlineRange = body.range(of: "\n") {
                    content = String(body[newlineRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return Entry(
            id: id,
            title: extractedTitle,
            content: content,
            type: data.type ?? .note,
            source: data.source ?? .manual,
            status: data.status ?? .raw,
            tags: data.tags ?? [],
            summary: data.summary,
            created: created,
            updated: updated,
            relativePath: data.relativePath ?? "inbox/\(id).md",
            attachmentURLs: data.attachmentURLs ?? []
        )
    }
    
    public static func extractFrontmatter(_ markdown: String) -> String? {
        let trimmedContent = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedContent.hasPrefix("---") else {
            return nil
        }
        
        guard let endRange = trimmedContent.range(of: "---", range: trimmedContent.index(trimmedContent.startIndex, offsetBy: 3)..<trimmedContent.endIndex) else {
            return nil
        }
        
        let start = trimmedContent.index(trimmedContent.startIndex, offsetBy: 3)
        let end = endRange.lowerBound
        
        return String(trimmedContent[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func extractBody(_ markdown: String) -> String {
        let trimmedContent = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedContent.hasPrefix("---") else {
            return markdown
        }
        
        guard let endRange = trimmedContent.range(of: "---", range: trimmedContent.index(trimmedContent.startIndex, offsetBy: 3)..<trimmedContent.endIndex) else {
            return markdown
        }
        
        let bodyStart = endRange.upperBound
        return String(trimmedContent[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
