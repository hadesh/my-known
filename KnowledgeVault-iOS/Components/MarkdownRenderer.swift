import SwiftUI

struct MarkdownRenderer: View {
    let content: String
    
    var body: some View {
        Text(attributedString)
            .font(.body)
    }
    
    private var attributedString: AttributedString {
        var result = AttributedString(content)
        
        let patterns: [(NSRegularExpression, (AttributedString) -> AttributedString)] = [
            (try! NSRegularExpression(pattern: "^#{1,6}\\s(.+)$", options: [.anchorsMatchLines]), headingTransformer),
            (try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*"), boldTransformer),
            (try! NSRegularExpression(pattern: "`(.+?)`"), codeTransformer),
            (try! NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)"), linkTransformer)
        ]
        
        for (regex, transformer) in patterns {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches.reversed() {
                if let range = Range(match.range, in: content) {
                    let substring = String(content[range])
                    var attrStr = AttributedString(substring)
                    attrStr = transformer(attrStr)
                    
                    if let attrRange = Range(match.range, in: result) {
                        result.replaceSubrange(attrRange, with: attrStr)
                    }
                }
            }
        }
        
        return result
    }
    
    private func headingTransformer(_ attrStr: AttributedString) -> AttributedString {
        var result = attrStr
        result.font = .headline
        return result
    }
    
    private func boldTransformer(_ attrStr: AttributedString) -> AttributedString {
        var result = attrStr
        result.font = .body.bold()
        return result
    }
    
    private func codeTransformer(_ attrStr: AttributedString) -> AttributedString {
        var result = attrStr
        result.font = .system(.body, design: .monospaced)
        result.backgroundColor = Color.gray.opacity(0.1)
        return result
    }
    
    private func linkTransformer(_ attrStr: AttributedString) -> AttributedString {
        var result = attrStr
        result.foregroundColor = .blue
        result.link = URL(string: extractURL(from: String(result.characters)))
        return result
    }
    
    private func extractURL(from text: String) -> String {
        let pattern = "\\((.+?)\\)"
        guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return ""
        }
        return String(text[range])
    }
}

#Preview {
    MarkdownRenderer(content: "# Title\n\nThis is **bold** text and `code` snippet.\n\n[Link](https://example.com)")
}