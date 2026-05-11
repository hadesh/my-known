import Foundation

public struct FrontmatterData {
    public var id: String?
    public var title: String?
    public var type: EntryType?
    public var source: EntrySource?
    public var status: EntryStatus?
    public var tags: [String]?
    public var summary: String?
    public var created: Date?
    public var updated: Date?
    public var relativePath: String?
    public var attachmentURLs: [URL]?
}

public enum FrontmatterParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static var sourceAliasMap: [String: EntrySource] {
        [
            "manual": .manual,
            "camera": .camera,
            "camera-roll": .camera,
            "share": .share,
            "share-extension": .share,
            "clipboard": .clipboard
        ]
    }
    
    public static func parse(_ content: String) -> (frontmatter: FrontmatterData?, body: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedContent.hasPrefix("---") {
            return (nil, content)
        }
        
        guard let endRange = trimmedContent.range(of: "---", range: trimmedContent.index(trimmedContent.startIndex, offsetBy: 3)..<trimmedContent.endIndex) else {
            return (nil, content)
        }
        
        let frontmatterStart = trimmedContent.index(trimmedContent.startIndex, offsetBy: 3)
        let frontmatterEnd = endRange.lowerBound
        let frontmatterContent = String(trimmedContent[frontmatterStart..<frontmatterEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let bodyStart = endRange.upperBound
        let bodyContent = String(trimmedContent[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let data = parseFrontmatterContent(frontmatterContent)
        
        return (data, bodyContent)
    }
    
    private static func parseFrontmatterContent(_ content: String) -> FrontmatterData {
        var data = FrontmatterData()
        let lines = content.components(separatedBy: .newlines)
        var currentKey: String?
        var currentArray: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            if trimmedLine.hasPrefix("-") && currentKey != nil {
                let value = trimmedLine.dropFirst().trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                currentArray.append(value)
            } else if let colonIndex = trimmedLine.firstIndex(of: ":") {
                if let key = currentKey, !currentArray.isEmpty {
                    assignArrayValue(to: &data, key: key, array: currentArray)
                }
                currentArray = []
                
                let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if value.hasPrefix("[") && value.hasSuffix("]") {
                    let arrayContent = value.dropFirst().dropLast()
                    let items = arrayContent.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                    assignArrayValue(to: &data, key: key, array: items)
                } else if value.isEmpty || value == "[" {
                    currentKey = key
                } else {
                    assignScalarValue(to: &data, key: key, value: value)
                }
            }
        }
        
        if let key = currentKey, !currentArray.isEmpty {
            assignArrayValue(to: &data, key: key, array: currentArray)
        }
        
        return data
    }
    
    private static func assignScalarValue(to data: inout FrontmatterData, key: String, value: String) {
        let cleanedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        switch key.lowercased() {
        case "id":
            data.id = cleanedValue
        case "title":
            data.title = cleanedValue
        case "type":
            data.type = EntryType(rawValue: cleanedValue)
        case "source":
            data.source = parseSource(cleanedValue)
        case "status":
            data.status = EntryStatus(rawValue: cleanedValue)
        case "summary":
            data.summary = cleanedValue
        case "relativepath", "relative_path", "path":
            data.relativePath = cleanedValue
        case "created", "date":
            data.created = dateFormatter.date(from: cleanedValue)
        case "updated", "modified":
            data.updated = dateFormatter.date(from: cleanedValue)
        case "attachments", "attachment_urls", "attachmenturls":
            let urls = cleanedValue.split(separator: ",").compactMap { URL(string: $0.trimmingCharacters(in: .whitespaces)) }
            data.attachmentURLs = urls
        default:
            break
        }
    }
    
    private static func assignArrayValue(to data: inout FrontmatterData, key: String, array: [String]) {
        switch key.lowercased() {
        case "tags":
            data.tags = array
        case "attachments", "attachment_urls", "attachmenturls":
            data.attachmentURLs = array.compactMap { URL(string: $0) }
        default:
            break
        }
    }
    
    private static func parseSource(_ value: String) -> EntrySource? {
        let lowercased = value.lowercased()
        
        if let canonical = sourceAliasMap[lowercased] {
            return canonical
        }
        
        return EntrySource(rawValue: lowercased)
    }
    
    public static func serialize(data: FrontmatterData) -> String {
        var lines: [String] = []
        lines.append("---")
        
        if let id = data.id {
            lines.append("id: \(id)")
        }
        if let title = data.title {
            lines.append("title: \"\(escapeYAMLString(title))\"")
        }
        if let type = data.type {
            lines.append("type: \(type.rawValue)")
        }
        if let source = data.source {
            lines.append("source: \(source.rawValue)")
        }
        if let status = data.status {
            lines.append("status: \(status.rawValue)")
        }
        if let summary = data.summary {
            lines.append("summary: \"\(escapeYAMLString(summary))\"")
        }
        if let created = data.created {
            lines.append("created: \(dateFormatter.string(from: created))")
        }
        if let updated = data.updated {
            lines.append("updated: \(dateFormatter.string(from: updated))")
        }
        if let relativePath = data.relativePath {
            lines.append("relativePath: \"\(escapeYAMLString(relativePath))\"")
        }
        if let tags = data.tags, !tags.isEmpty {
            lines.append("tags:")
            for tag in tags {
                lines.append("  - \"\(escapeYAMLString(tag))\"")
            }
        }
        if let attachments = data.attachmentURLs, !attachments.isEmpty {
            lines.append("attachments:")
            for url in attachments {
                lines.append("  - \"\(url.absoluteString)\"")
            }
        }
        
        lines.append("---")
        
        return lines.joined(separator: "\n")
    }
    
    private static func escapeYAMLString(_ string: String) -> String {
        return string.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
