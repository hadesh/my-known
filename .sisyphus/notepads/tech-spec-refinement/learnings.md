
## Task 5: LLM Module Implementation - 2026-05-09

### 完成的组件

1. **LLMProvider.swift** - 协议定义
   - 使用 `nonisolated` 修饰符解决 actor 隔离问题
   - 添加 `embeddingModel: String?` 属性支持嵌入模型

2. **KeychainManager.swift** - 钥匙串管理
   - 使用 Security 框架 API
   - 属性 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 确保安全性
   - 支持增删查操作

3. **SSEParser.swift** - SSE流解析器
   - 使用 `AsyncThrowingStream<String, Error>` 实现异步流
   - 解析 `data: {...}` 格式
   - 支持 `[DONE]` 终止信号
   - 提取 `delta.content` 字段

4. **OpenAIProvider.swift** - OpenAI实现
   - Endpoint: `https://api.openai.com/v1/chat/completions`
   - 使用 `Authorization: Bearer {apiKey}` 头
   - 流式响应处理

5. **QwenProvider.swift** - 通义千问实现
   - Endpoint: `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
   - 适配阿里云API格式

6. **AnthropicProvider.swift** - Anthropic实现
   - 独立 `system` 字段（顶层，不在messages数组中）
   - Header: `anthropic-version: 2023-06-01`
   - 认证: `x-api-key: {apiKey}`
   - 将system消息从messages中分离出来单独处理

7. **CustomProvider.swift** - 自定义Provider实现
   - 支持用户自定义 `baseURL` 和 `apiKey`
   - Endpoint 拼接: `baseURL.appendingPathComponent("chat/completions")`
   - 可选嵌入支持

8. **LLMAgent.swift** - Actor + OrganizationResult
   - actor 隔离确保线程安全
   - `OrganizationResult` struct 包含: entryID, suggestedTitle, suggestedTags, suggestedTopic
   - 方法: chat(), embed(), organizeEntries(), answer(), fallbackChat()
   - 使用 `nonisolated` 属性满足协议要求

### 关键实现细节

#### Actor隔离与协议遵循
当actor遵循协议时，协议属性需要标记为`nonisolated`:
```swift
public protocol LLMProvider: Sendable {
    nonisolated var name: String { get }
    nonisolated var baseURL: URL { get }
    nonisolated var apiKey: String { get }
    nonisolated var embeddingModel: String? { get }
    // ...
}
```

#### SSE流解析
使用 `URLSession.bytes(for:)` 获取异步字节流，配合 `AsyncThrowingStream`:
```swift
public actor SSEParser {
    public func parseStream(from response: URLResponse, bytes: URLSession.AsyncBytes) 
        -> AsyncThrowingStream<String, Error> {
        // 解析 data: {...} 和 [DONE] 信号
    }
}
```

#### Anthropic特殊处理
Anthropic API将system消息作为顶层字段而非messages数组中:
```swift
// 从messages中提取system消息
var systemMessage: String? = nil
var userMessages: [[String: Any]] = []
for message in messages {
    if message.role == .system {
        systemMessage = message.content
    } else {
        userMessages.append(["role": message.role.rawValue, "content": message.content])
    }
}
// 将system添加到body顶层
if let system = systemMessage {
    body["system"] = system
}
```

### 遇到的编译错误与解决

1. **错误**: `value of type 'any LLMProvider' has no member 'embeddingModel'`
   - **解决**: 在协议中添加 `var embeddingModel: String? { get }`

2. **错误**: `type 'OpenAIProvider' does not conform to protocol 'LLMProvider'`
   - **原因**: `embeddingModel` 是 `String` 但协议要求 `String?`
   - **解决**: 将存储属性改为计算属性并包装为Optional

3. **错误**: `conformance of 'OpenAIProvider' to protocol 'LLMProvider' crosses into actor-isolated code`
   - **原因**: actor中的属性默认是隔离的
   - **解决**: 协议属性标记为 `nonisolated`

### 验证结果

- ✅ swift build 无错误通过
- ✅ 8个文件均存在于 LLM 目录
- ✅ AnthropicProvider 包含顶层 `system` 字段
- ✅ SSEParser 包含 `AsyncThrowingStream`
- ✅ KeychainManager 使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- ✅ 无第三方依赖（Alamofire、Combine等）

## Task 7: SearchEngine Implementation Learnings

### 2026-05-09

**SearchEngine 协议设计要点：**
- 使用 actor 实现 SearchEngineImpl 保证线程安全
- MarkdownFile struct 作为独立的数据结构，与 Entry 分离
- SearchError 枚举包含 .notImplemented 用于 Phase 1 占位

**混合搜索权重策略：**
- 从 VaultConfig.hybridAlpha 读取权重（默认 0.4）
- FTS 权重 α = hybridAlpha，语义权重 β = 1 - hybridAlpha
- BM25 分数为负值，归一化前需取绝对值

**Min-Max 归一化实现：**
```swift
private func minMaxNormalize(_ scores: [(String, Double)]) -> [(String, Double)] {
    guard !scores.isEmpty else { return [] }
    let minScore = scores.map { $0.1 }.min() ?? 0
    let maxScore = scores.map { $0.1 }.max() ?? 1
    guard maxScore > minScore else { return scores.map { ($0.0, 0.5) } }
    let range = maxScore - minScore
    return scores.map { id, score in
        let normalized = (score - minScore) / range
        return (id, normalized)
    }
}
```

**Phase 1 语义搜索占位：**
- .semantic mode 直接 throw SearchError.notImplemented
- 混合搜索中 semanticResults 为空数组
- Phase 2 实现时只需替换语义搜索逻辑部分

**FTS5 分数处理：**
- SQLite FTS5 返回的 rank 为负值（越小相关性越高）
- 取 abs(score) 后归一化
- 通过 triggers 自动维护 FTS 索引，无需手动管理


## Task 9: RAGPipeline + PromptBuilder Implementation - 2026-05-09

### 完成的组件

1. **RAGPipeline.swift** - RAG 流水线
   - RAGPipeline struct 包含: searchEngine, llmAgent, fileManager
   - RAGOptions struct 包含: topK(默认5), mode(默认.hybrid), maxContextTokens(默认8000)
   - query(question:options:) 方法返回 AsyncStream<String>

2. **PromptBuilder.swift** - 提示构建器
   - ContextSnippet struct 包含: fileID, title, path, content
   - buildSystemPrompt(contexts:) 静态方法
   - estimateTokens(_:) 使用 text.count / 4 估算
   - truncateContexts(_:maxTokens:) 按 token 预算截断

### 关键实现细节

#### Token 估算与截断
- 粗略估算：每个 token 约 4 个字符
- 截断策略：完整片段优先，最后片段可截断，保留至少 50 tokens

#### Swift 多行字符串格式注意
- 错误: """You are...""" (内容必须在换行后)
- 正确: """\nYou are...\n"""

### 设计决策

- 不持久化对话历史: RAGPipeline 只接受传入的 options，不保存状态
- 错误处理策略: 加载 Entry 失败时回退到使用 SearchResult.snippet
- ContextSnippet path 字段预留用于未来文件路径追踪

### 验证结果

- swift build 无错误通过
- func query(question: String, options: RAGOptions) 存在于 RAGPipeline.swift
- func estimateTokens 存在于 PromptBuilder.swift
- maxContextTokens = 8000 默认值正确设置
- 已删除占位文件 RAG.swift

