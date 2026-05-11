import Foundation

public actor SSEParser {
    private var buffer = ""
    
    public init() {}
    
    public func parseStream(from response: URLResponse, bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var iterator = bytes.makeAsyncIterator()
                    
                    while let byte = try await iterator.next() {
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        if buffer.hasSuffix("\n\n") || buffer.hasSuffix("\r\n\r\n") {
                            await processBuffer(continuation: continuation)
                        }
                    }
                    
                    if !buffer.isEmpty {
                        await processBuffer(continuation: continuation)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func processBuffer(continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        let lines = buffer.components(separatedBy: .newlines)
        buffer = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            }
            
            if trimmed == "[DONE]" {
                continuation.finish()
                return
            }
            
            if trimmed.hasPrefix("data: ") {
                let dataContent = String(trimmed.dropFirst(6))
                
                if dataContent == "[DONE]" {
                    continuation.finish()
                    return
                }
                
                if let content = extractContent(from: dataContent) {
                    continuation.yield(content)
                }
            }
        }
    }
    
    private func extractContent(from dataString: String) -> String? {
        guard let data = dataString.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Anthropic 流式格式：{"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
                if let type_ = json["type"] as? String,
                   type_ == "content_block_delta",
                   let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    return text
                }
                
                // OpenAI / Qwen 流式格式：{"choices":[{"delta":{"content":"..."}}]}
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    return content
                }
                
                // 非流式回退：{"choices":[{"message":{"content":"..."}}]}
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                }
                
                // Anthropic 旧格式（非官方流式）：{"delta":{"text":"..."}}
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    return text
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    public func reset() {
        buffer = ""
    }
}

public enum SSEParserError: Error {
    case invalidResponse
    case decodingFailed
    case connectionClosed
}
