# AI 个人知识库 Agent — 技术方案文档

> **代号**: KnowledgeVault  
> **版本**: v0.1.0-draft  
> **日期**: 2026-05-09  
> **定位**: iOS 优先的纯端侧 AI 个人知识管理工具

---

## 1. 产品概述

### 1.1 一句话定位

**"把碎片变结构，让知识来找你"** —— 个人随身知识库，AI 自动整理、智能问答。

### 1.2 核心价值

| 维度 | 说明 |
|------|------|
| **纯端侧** | 所有数据存在用户设备上，隐私安全 |
| **文本优先** | 知识库 = 纯 Markdown 文件夹，可导出、可同步、可用任意编辑器打开 |
| **AI 加速** | 自动分类、打标签、摘要、语义搜索、RAG 问答 |
| **用户自带 Key** | 用户配置自己的 LLM API key，零后端成本 |
| **iCloud 同步** | 多设备间自动同步知识库文件 |

### 1.3 目标用户

- 知识工作者、研究者、开发者
- 有大量碎片信息需要整理的人
- 重视数据隐私、不希望数据上云的用户
- 习惯 Markdown 和 Obsidian/Logseq 等工具的用户

---

## 2. 架构总览

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS / macOS App                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                   Presentation Layer (SwiftUI)          │  │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │  │
│  │  │ Inbox   │  │ Browse   │  │ Search   │  │ Chat   │  │  │
│  │  │ View    │  │ View     │  │ View     │  │ View   │  │  │
│  │  └────┬────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │  │
│  │       └────────────┼─────────────┼────────────┼───────┘  │  │
│  └────────────────────┼─────────────┼────────────┼────────┘  │
│                       │             │            │            │
│  ┌────────────────────┴─────────────┴────────────┴────────┐  │
│  │              Core Logic Layer (Swift Package)            │  │
│  │  ┌──────────────┐  ┌───────────┐  ┌─────────────────┐  │  │
│  │  │ FileManager  │  │ LLMAgent  │  │ EmbeddingEngine │  │  │
│  │  │  · 文件读写   │  │  · 配置   │  │  · 向量生成      │  │  │
│  │  │  · Markdown   │  │  · 调用   │  │  · 相似度计算    │  │  │
│  │  │  · Frontmatter│  │  · 重试   │  │  · 增量更新      │  │  │
│  │  │  · Git Track  │  │  · 流式   │  │  · 缓存          │  │  │
│  │  └──────┬───────┘  └─────┬─────┘  └────────┬────────┘  │  │
│  │         └────────────────┼─────────────────┘            │  │
│  │                          │                              │  │
│  │  ┌───────────────────────┴──────────────────────────┐  │  │
│  │  │              SearchEngine                         │  │  │
│  │  │  · SQLite FTS5 全文搜索                           │  │  │
│  │  │  · 语义搜索（向量余弦相似度）                      │  │  │
│  │  │  · 混合排序                                        │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              Storage Layer                               │  │
│  │  ┌────────────────┐  ┌─────────────────┐               │  │
│  │  │ File System    │  │ SQLite (Index)  │               │  │
│  │  │ ~/KnowledgeVault│  │   · file_index  │               │  │
│  │  │   · Markdown   │  │   · fts_index   │               │  │
│  │  │   · Attachments│  │   · embeddings  │               │  │
│  │  └───────┬────────┘  └────────┬────────┘               │  │
│  │          │                    │                         │  │
│  │  ┌───────┴────────────────────┴────────┐               │  │
│  │  │         iCloud Drive (NSFileCoordinator) │          │  │
│  │  │         多设备同步                     │            │  │
│  │  └──────────────────────────────────────┘               │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              LLM Gateway (用户配置)                      │  │
│  │  · OpenAI  · Anthropic  · 通义千问  · Groq  · 自定义    │  │
│  │  API key 存系统 Keychain，HTTPS 直接调用                 │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 分层说明

| 层级 | 职责 | 复用策略 |
|------|------|---------|
| **Core Logic** | 文件管理、LLM 调用、搜索、Embedding | Swift Package，iOS + macOS 共享 |
| **Presentation** | SwiftUI 界面 | iOS 优先，macOS 适配布局 |
| **Storage** | 文件系统 + SQLite 索引 | 跨平台复用 |
| **iCloud Sync** | NSFileCoordinator + NSFilePresenter | iOS + macOS 复用 |

---

## 3. 知识库文件结构

### 3.1 目录布局

```
KnowledgeVault/                    # 根目录（iCloud Drive 中）
├── MEMORY.md                      # 🧠 长期记忆（精炼知识摘要）
├── config.json                    # ⚙️ 用户配置
│
├── inbox/                         # 📥 收件箱（未整理的碎片）
│   ├── 20260509-153021-a7b3.md    #   命名: YYYYMMDD-HHmmss-{hash}.md
│   └── 20260509-160045-c9d2.md
│
├── daily/                         # 📂 每日记录
│   ├── 2026-05-09.md              #   命名: YYYY-MM-DD.md
│   └── 2026-05-08.md
│
├── topics/                        # 📂 主题知识（按领域）
│   ├── programming.md
│   ├── design.md
│   ├── business.md
│   └── health.md
│
├── attachments/                   # 📎 附件（图片、文件）
│   └── 20260509-153021-a7b3.jpg
│
└── .index/                        # 🔍 索引缓存（自动生成的，不跟踪）
    ├── sqlite.db                  #   SQLite 索引数据库
    └── embeddings.json            #   向量索引缓存
```

### 3.2 Markdown 文件格式

#### 收件箱条目

```markdown
---
id: "20260509-153021-a7b3"
type: "note"           # note | screenshot | voice | link | file
source: "manual"       # manual | camera-roll | share-extension | clipboard
created: "2026-05-09T15:30:21+08:00"
updated: "2026-05-09T15:30:21+08:00"
status: "raw"          # raw | reviewed | organized
tags: []
title: ""
summary: ""
---

# [AI 生成标题]

[原始内容]

---
*Generated by KnowledgeVault*
```

#### 主题文件

```markdown
---
topic: "programming"
title: "React 性能优化"
created: "2026-05-07T10:00:00+08:00"
updated: "2026-05-09T16:00:00+08:00"
tags: [react, performance, optimization]
---

# React 性能优化

## 核心要点
useMemo 用于缓存计算结果，避免不必要的重复计算。

## 适用场景
1. 昂贵的计算（数据转换、过滤大量数据）
2. 引用相等性依赖（传给子组件的对象/数组）
3. 避免子组件不必要的 re-render

## 反面模式
- 不要过度使用，先测量再优化

---
*Last organized: 2026-05-09*
```

#### MEMORY.md（长期记忆）

```markdown
# MEMORY.md - 个人长期记忆

## 技术积累
- React 性能优化：useMemo 缓存计算，React.memo 避免重渲染，先测量再优化
- ...

## 学习笔记
- 2026-05-09: 学习了 React 虚拟列表优化方案
- ...

## 想法与灵感
- 考虑用 KnowledgeVault 管理所有技术笔记
- ...

---
*Last updated: 2026-05-09*
```

### 3.3 配置文件

```json
{
  "version": 1,
  "llm": {
    "default_provider": "qwen",
    "providers": {
      "openai": {
        "enabled": true,
        "base_url": "https://api.openai.com/v1",
        "api_key_ref": "keychain:openai",
        "model_chat": "gpt-4o-mini",
        "model_embedding": "text-embedding-3-small"
      },
      "qwen": {
        "enabled": true,
        "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "api_key_ref": "keychain:qwen",
        "model_chat": "qwen-plus",
        "model_embedding": "text-embedding-v3"
      }
    }
  },
  "organize": {
    "auto_organize_inbox": true,
    "organize_interval_minutes": 30,
    "batch_size": 5
  },
  "sync": {
    "icloud_enabled": true,
    "git_enabled": false
  }
}
```

---

## 4. 知识流转设计

```
┌──────────────────────────────────────────────────────────────┐
│                       知识流转管道                            │
│                                                              │
│  输入 ────→ inbox/ ────→ 整理 ────→ topics/ ────→ 提炼 ──→   │
│   │           │            │            │             │      │
│   │ 随手记     │ AI 分类     │ 移动到      │ 写入         │      │
│   │ 截图/语音  │ 打标签      │ 主题文件     │ MEMORY.md    │      │
│   │ 链接/文字  │ 生成摘要    │ 合并更新     │              │      │
│   │           │            │            │             │      │
│   └───────────┴────────────┴────────────┴─────────────┘      │
│                                                              │
│  daily/  ←  每天自动汇总 inbox 中已整理的条目                  │
│                                                              │
│  定期回顾（每周/每月）：                                       │
│  - 回顾 daily/ 文件，将重要信息提炼到 topics/ 和 MEMORY.md    │
│  - 清理过期的 inbox 条目                                     │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 状态机

```
              创建
               │
               ▼
            ┌─────┐
            │ raw │ ← 新创建的条目
            └──┬──┘
               │ AI 整理
               ▼
          ┌─────────┐
          │ reviewed │ ← AI 已分类/打标签
          └────┬────┘
               │ 用户确认 / 自动归档
               ▼
          ┌───────────┐
          │ organized │ ← 已移动到 topics/
          └───────────┘
```

---

## 5. 核心模块详细设计

### 5.1 FileManager（文件管理）

```swift
/// 核心协议
protocol KnowledgeVaultFileManager {
    /// 知识库根目录 URL
    var vaultURL: URL { get }
    
    /// 创建新条目到 inbox
    func createEntry(content: String, type: EntryType, source: EntrySource) async throws -> Entry
    
    /// 读取条目
    func readEntry(id: String) async throws -> Entry
    
    /// 更新条目
    func updateEntry(id: String, content: String, tags: [String]) async throws
    
    /// 移动条目（inbox → topics/）
    func moveEntry(id: String, toTopic: String) async throws
    
    /// 列出某目录下的所有条目
    func listEntries(in directory: VaultDirectory) async throws -> [Entry]
    
    /// 搜索条目（全文 + 语义）
    func search(query: String, mode: SearchMode) async throws -> [SearchResult]
    
    /// 删除条目
    func deleteEntry(id: String) async throws
    
    /// 导出条目为 Markdown 文件 URL（用于分享）
    func exportEntry(id: String) async throws -> URL
}
```

**关键实现点**：
- 使用 `NSFileCoordinator` 进行读写，保证 iCloud 同步安全
- Markdown 解析：使用自定义轻量解析器或 [Publish](https://github.com/JohnSundell/Publish) 的 frontmatter 解析
- 文件操作全部异步，支持流式大文件

### 5.2 LLMAgent（AI 代理）

```swift
/// LLM Provider 抽象
protocol LLMProvider {
    var name: String { get }
    var baseURL: URL { get }
    var apiKey: String { get }
    
    /// 聊天补全（支持流式）
    func chatCompletion(
        messages: [ChatMessage],
        model: String,
        temperature: Double
    ) async throws -> AsyncStream<String>
    
    /// Embedding 生成
    func embedding(text: String, model: String) async throws -> [Float]
}

/// 具体 Provider 实现
struct OpenAIProvider: LLMProvider { ... }
struct QwenProvider: LLMProvider { ... }
struct AnthropicProvider: LLMProvider { ... }
struct CustomProvider: LLMProvider { ... }

/// LLM Gateway
actor LLMAgent {
    private var config: LLMConfig
    private var providers: [String: LLMProvider]
    
    /// 使用默认 provider 执行聊天
    func chat(messages: [ChatMessage]) async throws -> AsyncStream<String>
    
    /// 使用默认 provider 生成 embedding
    func embed(text: String) async throws -> [Float]
    
    /// 整理条目（批量）
    func organizeEntries(entries: [Entry]) async throws -> [OrganizationResult]
    
    /// 生成 RAG 回答
    func answer(question: String, context: [String]) async throws -> AsyncStream<String>
    
    /// 切换 provider
    func setDefaultProvider(_ name: String)
    
    /// 故障切换
    func fallbackChat(messages: [ChatMessage]) async throws -> AsyncStream<String>
}
```

**Provider 适配策略**：
- 所有 Provider 统一为 OpenAI 兼容接口（`/v1/chat/completions` 和 `/v1/embeddings`）
- Anthropic 通过适配层转换
- 用户可通过自定义 base_url 接入任何兼容服务

### 5.3 SearchEngine（搜索引擎）

```swift
enum SearchMode {
    case fulltext       // SQLite FTS5
    case semantic       // 向量相似度
    case hybrid         // 混合排序
}

protocol SearchEngine {
    /// 索引文件
    func indexFile(_ file: MarkdownFile) async throws
    
    /// 更新索引
    func updateIndex(fileID: String) async throws
    
    /// 搜索
    func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult]
    
    /// 重建索引
    func rebuildIndex() async throws
}
```

**混合搜索排序**：

```
最终得分 = α × FTS得分 + β × 语义相似度得分

α = 0.4, β = 0.6（默认权重，用户可调）
```

### 5.4 EmbeddingEngine（向量引擎）

```swift
actor EmbeddingEngine {
    private var index: EmbeddingIndex
    
    /// 为文件生成 embedding
    func generateEmbedding(for fileID: String) async throws
    
    /// 批量生成（后台任务）
    func batchGenerate(for fileIDs: [String]) async throws
    
    /// 语义搜索
    func semanticSearch(query: String, topK: Int) async throws -> [FileSimilarity]
    
    /// 检查是否需要更新
    func needsUpdate(fileID: String) async -> Bool
    
    /// 增量更新（只更新被修改的文件）
    func incrementalUpdate() async throws
}
```

**增量更新策略**：
- 每次文件更新时记录 `updated_at`
- `embeddings.json` 中记录 `embedding_generated_at`
- `updated_at > embedding_generated_at` → 需要重新生成

### 5.5 RAGPipeline（问答管道）

```swift
struct RAGPipeline {
    let searchEngine: SearchEngine
    let llmAgent: LLMAgent
    let fileManager: KnowledgeVaultFileManager
    
    /// 执行 RAG 问答
    func query(question: String, options: RAGOptions) async throws -> AsyncStream<String> {
        // 1. 检索
        let results = try await searchEngine.search(
            query: question,
            mode: .hybrid,
            limit: options.topK
        )
        
        // 2. 加载相关文件内容
        let contexts = try await results.map { result in
            let file = try await fileManager.readEntry(id: result.fileID)
            return ContextSnippet(
                file: file.title ?? file.id,
                path: file.relativePath,
                content: file.content
            )
        }
        
        // 3. 组装 prompt
        let systemPrompt = buildSystemPrompt(contexts: contexts)
        let messages = [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: question)
        ]
        
        // 4. 流式生成
        return try await llmAgent.chat(messages: messages)
    }
}
```

### 5.6 SyncManager（同步管理）

```swift
actor SyncManager {
    /// iCloud 同步
    func enableICloud() async throws
    
    /// 检查同步状态
    func syncStatus() async -> SyncStatus
    
    /// 冲突解决策略
    func handleConflict(local: File, remote: File) async -> ConflictResolution
    
    /// 手动触发同步
    func syncNow() async throws
}
```

**iCloud 实现方案**：
- 使用 `NSFileCoordinator` + `NSFilePresenter`
- 知识库目录放在 iCloud Drive 的 `com.xxx.knowledgevault/` 下
- 监听 `NSFileCoordinator` 的协调读写事件
- 冲突时采用 **最后写入胜出 + 保存冲突副本**

---

## 6. 项目结构

```
KnowledgeVault/
├── KnowledgeVault.xcodeproj/
│
├── Packages/
│   └── KnowledgeVaultCore/            # 🔑 核心逻辑包（iOS + macOS 共享）
│       ├── Package.swift
│       ├── Sources/
│       │   ├── FileManager/
│       │   │   ├── VaultFileManager.swift
│       │   │   ├── MarkdownParser.swift
│       │   │   ├── Entry.swift
│       │   │   └── VaultDirectory.swift
│       │   │
│       │   ├── LLM/
│       │   │   ├── LLMAgent.swift
│       │   │   ├── LLMProvider.swift
│       │   │   ├── OpenAIProvider.swift
│       │   │   ├── QwenProvider.swift
│       │   │   ├── AnthropicProvider.swift
│       │   │   ├── ChatMessage.swift
│       │   │   └── LLMConfig.swift
│       │   │
│       │   ├── Search/
│       │   │   ├── SearchEngine.swift
│       │   │   ├── FTSSearch.swift
│       │   │   ├── SemanticSearch.swift
│       │   │   └── HybridSearch.swift
│       │   │
│       │   ├── Embedding/
│       │   │   ├── EmbeddingEngine.swift
│       │   │   └── EmbeddingIndex.swift
│       │   │
│       │   ├── RAG/
│       │   │   ├── RAGPipeline.swift
│       │   │   └── PromptBuilder.swift
│       │   │
│       │   ├── Sync/
│       │   │   ├── SyncManager.swift
│       │   │   └── ConflictResolver.swift
│       │   │
│       │   └── Models/
│       │       ├── Entry.swift
│       │       ├── SearchResult.swift
│       │       ├── OrganizationResult.swift
│       │       └── VaultConfig.swift
│       │
│       └── Tests/
│
├── KnowledgeVault-iOS/                # 📱 iOS App
│   ├── Info.plist
│   ├── AppDelegate.swift
│   ├── KnowledgeVaultApp.swift
│   │
│   ├── Features/
│   │   ├── Inbox/
│   │   │   ├── InboxView.swift
│   │   │   ├── InboxViewModel.swift
│   │   │   └── CreateEntryView.swift
│   │   │
│   │   ├── Browse/
│   │   │   ├── BrowseView.swift
│   │   │   ├── TopicListView.swift
│   │   │   ├── DailyView.swift
│   │   │   └── EntryDetailView.swift
│   │   │
│   │   ├── Search/
│   │   │   ├── SearchView.swift
│   │   │   └── SearchResultRow.swift
│   │   │
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── ChatMessageBubble.swift
│   │   │   └── ChatViewModel.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── LLMConfigView.swift
│   │       └── SyncSettingsView.swift
│   │
│   ├── Components/
│   │   ├── MarkdownRenderer.swift
│   │   ├── ShareSheet.swift
│   │   ├── DocumentPicker.swift
│   │   └── CameraCapture.swift
│   │
│   ├── Extensions/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.xcstrings
│
├── KnowledgeVault-macOS/              # 🖥️ macOS App（Phase 2）
│   └── ... (复用 KnowledgeVaultCore，调整 UI 布局)
│
└── ShareExtension/                    # 📤 iOS Share Extension（Phase 2）
    └── ... (从 Safari/其他 App 分享内容到 inbox)
```

---

## 7. 关键数据模型

### 7.1 Entry

```swift
struct Entry: Identifiable, Codable {
    let id: String                        // "20260509-153021-a7b3"
    var title: String?
    var content: String                   // Markdown 正文
    let type: EntryType                   // note | screenshot | voice | link | file
    let source: EntrySource               // manual | camera | share | clipboard
    var status: EntryStatus               // raw | reviewed | organized
    var tags: [String]
    var summary: String?
    let created: Date
    var updated: Date
    var relativePath: String              // "inbox/20260509-153021-a7b3.md"
    var attachmentURLs: [URL]             // 附件引用
}
```

### 7.2 SearchResult

```swift
struct SearchResult: Identifiable {
    let fileID: String
    let title: String?
    let snippet: String                   // 匹配片段
    let score: Double                     // 综合得分
    let searchMode: SearchMode            // 来自哪种搜索
    let tags: [String]
    let created: Date
}
```

### 7.3 ChatMessage

```swift
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole                    // user | assistant | system
    let content: String
    let timestamp: Date
    var isStreaming: Bool                 // 是否正在流式接收
    var citations: [Citation]             // 引用来源
}

struct Citation {
    let fileID: String
    let title: String
    let snippet: String
}
```

---

## 8. Prompt 设计

### 8.1 整理 Prompt

```
你是一个个人知识管理助手。请分析以下知识条目，完成以下任务：

1. 提取一个简洁的标题（中文，不超过 20 字）
2. 生成 3-5 个标签（使用中文）
3. 判断应该归入哪个主题，从以下已有主题中选择，或建议新主题：
   [动态列出已有主题列表]
4. 用 2-3 句话总结核心内容
5. 判断是否有值得写入 MEMORY.md 的重要信息

请以以下 JSON 格式返回，不要包含其他内容：
{
    "title": "标题",
    "tags": ["标签1", "标签2"],
    "suggested_topic": "主题名",
    "new_topic_suggestion": null,
    "summary": "摘要内容",
    "promote_to_memory": false,
    "memory_note": ""
}

待整理的条目内容：
---
{{entry_content}}
---
```

### 8.2 RAG 问答 Prompt

```markdown
你是用户的个人知识助手。请基于用户知识库中的资料回答问题。

## 相关知识

<!-- 以下内容来自用户的知识库文件 -->

{{#each contexts}}
[File: {{this.file}}]
{{this.content}}

{{/each}}

## 要求
- 基于以上资料回答
- 不要编造知识库里没有的内容
- 如果知识库中没有相关信息，请直说
- 注明每个观点的来源文件
- 用中文回答

## 用户问题
{{question}}
```

---

## 9. 开发路线图

### Phase 1: MVP（3-4 周）— iOS Only

| 周 | 任务 | 交付物 |
|----|------|--------|
| **W1** | 项目搭建 + Core Package | Swift Package 骨架，FileManager 基础 |
| | | Markdown 读写、Frontmatter 解析 |
| | | 知识库目录结构初始化 |
| **W2** | LLM Gateway | 多 Provider 配置、Keychain 存储 |
| | | OpenAI 兼容接口调用（流式） |
| | | 文字输入 → inbox 创建 |
| **W3** | 基础 UI + 基础问答 | Inbox/Browse/Settings 页面 |
| | | 直接调 LLM 问答（无 RAG） |
| | | Markdown 渲染 |
| **W4** | 打磨 + 测试 | 错误处理、加载状态 |
| | | TestFlight 内测 |

**Phase 1 不包含**：OCR、语音输入、Embedding、语义搜索、RAG、iCloud 同步

### Phase 2: 知识引擎（3-4 周）— iOS

| 任务 | 说明 |
|------|------|
| SQLite FTS 全文搜索 | 建立 FTS5 索引，关键词搜索 |
| Embedding + 语义搜索 | 调用 LLM embedding API，向量存储与检索 |
| 混合搜索 | FTS + 语义混合排序 |
| 自动整理 | 后台批量调 LLM 分类打标签 |
| 知识流转 | inbox → topics → MEMORY.md 自动化 |
| iCloud 同步 | NSFileCoordinator 集成 |
| 标签管理 | 标签浏览、筛选 |

### Phase 3: RAG + 完善（3-4 周）— iOS

| 任务 | 说明 |
|------|------|
| RAG 问答 | 检索 + 生成回答 + 引用来源 |
| OCR 输入 | Vision / ML Kit 截图转文字 |
| 语音输入 | 系统 Speech-to-Text |
| 链接抓取 | Readability 算法提取网页正文 |
| Share Extension | Safari 等 App 分享文章到 inbox |
| 导出分享 | Markdown 文件分享、zip 导出 |
| 增量 Embedding | 后台增量更新向量索引 |

### Phase 4: macOS + 跨平台（3-4 周）

| 任务 | 说明 |
|------|------|
| macOS App | 复用 Core Package，适配 macOS 布局 |
| Catalyst / SwiftUI for Mac | 同一套 UI 代码 |
| 菜单栏快捷输入 | macOS 特色功能 |
| iCloud 同步验证 | iOS ↔ macOS 双向同步 |
| 键盘快捷键 | macOS 效率优化 |

---

## 10. 技术选型

| 领域 | 选择 | 理由 |
|------|------|------|
| 语言 | Swift 6 | 现代 Swift，并发安全 |
| UI 框架 | SwiftUI | iOS 17+，一套代码跨 iOS/macOS |
| 跨平台核心 | Swift Package | iOS + macOS 共享代码 |
| 本地存储 | 文件系统（主）+ SQLite（索引） | 文本优先，索引加速 |
| Markdown 解析 | 自定义轻量解析 / Ink | 只解析 frontmatter + 正文 |
| FTS | SQLite FTS5 | iOS 内置，无需额外依赖 |
| 向量存储 | JSON 文件 / SQLite BLOB | 轻量，够 MVP 用 |
| LLM SDK | HTTP 直接调用 | 各平台接口差异大，手写最灵活 |
| iCloud | NSFileCoordinator + NSFilePresenter | Apple 官方方案 |
| 加密存储 | Keychain | API key 安全存储 |
| 异步 | Swift Concurrency (async/await, Actor) | 现代 Swift 并发 |
| 架构 | MVVM + Swift Package 分层 | 清晰、可测试 |

---

## 11. 隐私与安全

| 项目 | 策略 |
|------|------|
| 数据存储 | 全部在用户设备本地 |
| API Key | 存入系统 Keychain，不落地 |
| LLM 调用 | HTTPS 直连，不经过中间服务器 |
| iCloud 同步 | Apple 端到端加密（如启用高级数据保护） |
| 附件 | 本地存储，可选是否同步到 iCloud |
| 网络权限 | 仅 LLM API 域名，可配置白名单 |

---

## 12. 成本预估

| 项目 | 月成本（用户侧） |
|------|----------------|
| LLM API（聊天） | ¥10-50（视使用量） |
| LLM API（embedding） | ¥5-20 |
| iCloud 存储 | 免费（5GB）或 ¥6/月（50GB） |
| 服务器 | ¥0（纯端侧） |
| **合计** | **¥15-76/月** |

---

## 13. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| LLM API 不稳定 | 整理/搜索失败 | 多 Provider 故障切换 |
| 知识库文件过大 | 性能下降 | 分文件存储、延迟加载、分页 |
| iCloud 同步冲突 | 数据覆盖 | 冲突检测 + 保存冲突副本 |
| 用户 API key 用尽 | 功能不可用 | 用量提醒、降级到本地搜索 |
| Embedding 费用高 | 用户流失 | 按需生成（只索引搜索过的）、批量优惠模型 |

---

## 14. 命名备选

| 名称 | 说明 |
|------|------|
| **KnowledgeVault** | 知识保险箱，专业感 |
| **知匣** | 中文品牌名，知识宝匣 |
| **MemoMind** | 记忆+智慧 |
| **拾知** | 拾取知识，轻量感 |
| **SecondBrain** | 第二大脑，直白 |
| **Knowl** | 简短好记 |

---

*文档版本: v0.1.0 | 创建时间: 2026-05-09 | 维护: 虾大龙*
