# KnowledgeVault 技术方案细化实现计划

> **基于**: MyKnownTechSpec.md v0.1.0-draft  
> **版本**: v3.2（追加 iOS SwiftUI UI 层任务 Task 11~16）  
> **日期**: 2026-05-09  

---

## TL;DR

> **快速摘要**: 在 MyKnownTechSpec.md 架构基础上，补全所有实现层面的技术决策并输出可执行代码，使 KnowledgeVaultCore Swift Package 拥有完整的数据层、LLM 层、搜索层接口与实现骨架，并完成 iOS App 全部 SwiftUI 界面（Inbox/Browse/Search/Chat/Settings），所有接口签名严格与 MyKnownTechSpec.md 第 5 节和第 7 节一致。
>
> **交付物**:
> - `Packages/KnowledgeVaultCore/Package.swift`（含 GRDB 依赖）
> - `Sources/` 下所有模块的 Swift 文件骨架（protocol + actor + struct 定义）
> - `Sources/Storage/schema.sql`（完整 SQLite schema）
> - `Tests/` 下每个模块的单元测试（≥20 个 @Test 函数）
> - `KnowledgeVault-iOS/` 下全部 SwiftUI 视图（17 个文件：Inbox/Browse/Search/Chat/Settings + 共享组件）
>
> **估计规模**: XL（8 个实现模块 + 测试 + 6 个 SwiftUI 功能模块）
> **并行执行**: YES — 6 波次
> **关键路径**: Task 1 → Task 2 → Task 3/4/5/6（并行）→ Task 7/8/9（并行）→ Task 10 → Task 11 → Task 12~16（并行）

---

## Context

### 原始需求
MyKnownTechSpec.md 设计了一个 iOS 优先的纯端侧 AI 个人知识库，但停留在架构设计层，缺少实现层决策。

### 关键决策（已通过用户问答确认）
- **iOS 最低版本**: iOS 17+，使用 `@Observable` 宏
- **SQLite 封装**: GRDB.swift ≥6.0
- **Phase 1 含 FTS**: SQLite FTS5 全文搜索提前到 Phase 1
- **macOS Phase 4**: 正式规划，Core Package API 需跨平台兼容
- **项目起点**: 完全从零开始

### 技术调研结论
- SSE 流式解析：URLSession.bytes + AsyncThrowingStream 自实现，无三方依赖
- iCloud 同步：NSFileCoordinator + NSFilePresenter，`.index/` 目录排除同步
- 向量存储：SQLite BLOB（而非 JSON 文件），事务一致性更好
- 中文 FTS：`unicode61` 字级索引（Phase 1~2），Phase 3+ 可升级 FTS5WrapperTokenizer
- Actor 边界：5 个 actor（FileManager/LLMAgent/EmbeddingEngine/SyncManager/SSEParser）

### 接口规范说明
**本计划严格遵循 MyKnownTechSpec.md 的接口定义**：
- 数据模型：第 7 节（Entry/SearchResult/ChatMessage）
- 核心协议/actor：第 5 节（5.1~5.6）
- 在 spec 未覆盖的实现细节（如向量 BLOB 编解码、SSEParser actor）由本计划补充

---

## Work Objectives

### 核心目标
实现 KnowledgeVaultCore Swift Package 的完整骨架，包含所有模块的接口定义、数据模型、关键算法实现和单元测试，达到可直接在 Xcode 中编译通过的状态，且所有 public API 与 MyKnownTechSpec.md 完全一致。

### 具体交付物
- `Packages/KnowledgeVaultCore/Package.swift` — 含 GRDB.swift 依赖声明
- `Sources/Models/` — Entry, SearchResult, ChatMessage 等（**严格按第 7 节定义**）
- `Sources/Storage/` — SQLite schema + GRDB 操作封装
- `Sources/FileManager/` — KnowledgeVaultFileManager 协议 + VaultFileManagerImpl actor（**按第 5.1 节**）
- `Sources/LLM/` — LLMProvider 协议 + LLMAgent actor + 三个 Provider 实现 + SSEParser（**按第 5.2 节**）
- `Sources/Search/` — SearchEngine 协议 + SearchEngineImpl（**按第 5.3 节**）
- `Sources/Embedding/` — EmbeddingEngine actor（**按第 5.4 节**）
- `Sources/RAG/` — RAGPipeline struct + PromptBuilder（**按第 5.5 节**）
- `Sources/Sync/` — SyncManager actor + ConflictResolver（**按第 5.6 节**）
- `Tests/` — 每个模块对应测试文件

### Definition of Done
- [ ] `swift build` 在 KnowledgeVaultCore 包目录下无错误通过
- [ ] `swift test` 全部通过（≥ 20 个测试用例）
- [ ] 所有 protocol/actor/struct 的 public 方法签名与 MyKnownTechSpec.md 第 5 节和第 7 节完全一致

### Must Have
- GRDB.swift 作为唯一 SQLite 依赖
- 所有文件 IO 通过 NSFileCoordinator 包裹
- SSEParser 使用 AsyncThrowingStream，支持取消
- 向量存储使用 SQLite BLOB + Accelerate vDSP 余弦相似度
- Entry 使用 `id: String`（格式 `"20260509-153021-a7b3"`），**不使用 UUID**

### Must NOT Have（防止 AI 代码膨胀）
- 不引入 Alamofire、Combine、CoreData、SwiftData
- 不为每个属性写 JSDoc 注释（只注释复杂逻辑）
- 不过度抽象（不为 2 个 provider 提取 3 层继承）
- 不在 Phase 1 实现 Embedding/语义搜索（只建文件骨架）
- 不硬编码文件路径字符串（使用 URL 组合）
- **不擅自修改 spec 定义的 public 方法签名**

---

## Verification Strategy

### Test Decision
- **Infrastructure**: 使用 Swift Testing (Xcode 16)
- **Automated tests**: Tests-after（先骨架实现，后补测试）
- **Framework**: Swift Testing (`@Test`, `#expect`)

### QA Policy
每个任务包含 agent-executed QA 场景。Evidence 保存至 `.sisyphus/evidence/`。

- **Swift Package 编译**: `swift build` 命令验证
- **单元测试**: `swift test` 命令验证
- **接口一致性**: `grep` 对照 spec 签名逐项检查

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (立即开始 — 基础设施，无依赖):
├── Task 1: Package.swift 配置 + 目录结构 [quick]
└── Task 2: 数据模型定义 (Models/) [quick]

Wave 2 (Wave 1 完成后 — 核心模块，最大并行):
├── Task 3: KnowledgeVaultFileManager 协议 + Impl + FrontmatterParser (depends: 1, 2) [unspecified-high]
├── Task 4: SQLite Schema + GRDB DatabaseManager (depends: 1, 2) [unspecified-high]
├── Task 5: LLMProvider 协议 + LLMAgent + 四个 Provider（含 CustomProvider）+ SSEParser (depends: 1, 2) [unspecified-high]
└── Task 6: EmbeddingEngine actor + 余弦相似度 (depends: 1, 2) [unspecified-high]

Wave 3 (Wave 2 完成后 — 组合模块):
├── Task 7: SearchEngine 协议 + SearchEngineImpl（FTS + Hybrid）(depends: 3, 4) [unspecified-high]
├── Task 8: SyncManager + ConflictResolver + VaultDirectoryPresenter (depends: 3) [unspecified-high]
└── Task 9: RAGPipeline + PromptBuilder (depends: 5, 7) [unspecified-high]

Wave 4 (全部完成后 — 测试):
└── Task 10: 所有模块单元测试 (depends: 3~9) [unspecified-high]

Wave 5 (Wave 4 完成后 — iOS App 入口 + 共享组件):
└── Task 11: iOS App 入口 (KnowledgeVaultApp/AppDelegate) + Components/ 4 个共享组件 (depends: 10) [visual-engineering]

Wave 6 (Wave 5 完成后 — SwiftUI Feature 模块，最大并行):
├── Task 12: Inbox 功能 (InboxView/InboxViewModel/CreateEntryView) (depends: 11) [visual-engineering]
├── Task 13: Browse 功能 (BrowseView/TopicListView/DailyView/EntryDetailView) (depends: 11) [visual-engineering]
├── Task 14: 搜索界面 (SearchView/SearchResultRow) (depends: 11) [visual-engineering]
├── Task 15: AI 对话界面 (ChatView/ChatViewModel/ChatMessageBubble) (depends: 11) [visual-engineering]
└── Task 16: 设置页 (SettingsView/LLMConfigView/SyncSettingsView) (depends: 11) [visual-engineering]
```

### 依赖矩阵
- **1**: — → 2, 3, 4, 5, 6
- **2**: 1 → 3, 4, 5, 6
- **3**: 1, 2 → 7, 8
- **4**: 1, 2 → 7
- **5**: 1, 2 → 9
- **6**: 1, 2 → (Phase 2 使用)
- **7**: 3, 4 → 9
- **8**: 3 → (独立)
- **9**: 5, 7 → (独立)
- **10**: 3~9 → 11
- **11**: 10 → 12, 13, 14, 15, 16
- **12~16**: 11 → —

### Agent Dispatch Summary
- **Wave 1**: 2 tasks → `quick` × 2
- **Wave 2**: 4 tasks → `unspecified-high` × 4（并行）
- **Wave 3**: 3 tasks → `unspecified-high` × 3（并行）
- **Wave 4**: 1 task → `unspecified-high`
- **Wave 5**: 1 task → `visual-engineering`
- **Wave 6**: 5 tasks → `visual-engineering` × 5（并行）
- **Final**: 3 tasks → `quick` × 2 + `oracle` × 1（并行）

---

## TODOs

- [x] 1. Package.swift 配置 + 目录结构搭建

  **What to do**:
  - 在 `Packages/KnowledgeVaultCore/` 下创建 `Package.swift`，声明 Swift Tools Version 5.9，platforms `.iOS(.v17)`，products `.library(name: "KnowledgeVaultCore", targets: ["KnowledgeVaultCore"])`
  - 添加 GRDB.swift 依赖：`https://github.com/groue/GRDB.swift` `.upToNextMajor(from: "6.0.0")`
  - 创建完整目录结构：`Sources/KnowledgeVaultCore/Models/`、`Storage/`、`FileManager/`、`LLM/`、`Search/`、`Embedding/`、`RAG/`、`Sync/`、`Tests/KnowledgeVaultCoreTests/`
  - 每个子目录创建一个空占位 `.swift` 文件（`enum Placeholder {}`）让 Swift 能识别目标

  **Must NOT do**:
  - 不引入除 GRDB 之外的第三方依赖
  - 不创建 Xcode project 文件

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO（起点任务）
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 2~10
  - **Blocked By**: None

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 516 行起）— 项目目录结构（`Packages/KnowledgeVaultCore/` 布局）
  - Swift Package Manager 官方文档：`https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html`
  - GRDB.swift README SPM 集成：`https://github.com/groue/GRDB.swift#swift-package-manager`

  **Acceptance Criteria**:
  - [ ] `swift package resolve` 无错误，GRDB.swift 依赖解析成功
  - [ ] `swift build` 输出 `Build complete!`

  ```
  Scenario: Package 初始化成功
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift package resolve 2>&1
      2. swift build 2>&1
    Expected Result: 无 error，"Build complete!" 出现
    Evidence: .sisyphus/evidence/task-1-build.txt

  Scenario: 目录结构完整
    Tool: Bash
    Steps:
      1. ls Sources/KnowledgeVaultCore/ | sort
    Expected Result: 输出包含 Models Storage FileManager LLM Search Embedding RAG Sync（8 个子目录）
    Evidence: .sisyphus/evidence/task-1-dirs.txt
  ```

  **Commit**: YES（与 Task 2 合并）
  - Message: `feat(core): init Swift Package with GRDB dependency and data models`

- [x] 2. 数据模型定义（Sources/KnowledgeVaultCore/Models/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 7 节实现以下类型：
  - `Entry.swift`：
    ```swift
    struct Entry: Identifiable, Codable {
        let id: String                   // "20260509-153021-a7b3"
        var title: String?
        var content: String              // Markdown 正文
        let type: EntryType
        let source: EntrySource
        var status: EntryStatus
        var tags: [String]
        var summary: String?
        let created: Date
        var updated: Date
        var relativePath: String
        var attachmentURLs: [URL]
    }
    enum EntryType: String, Codable { case note, screenshot, voice, link, file }
    enum EntrySource: String, Codable { case manual, camera, share, clipboard }
    enum EntryStatus: String, Codable { case raw, reviewed, organized }
    ```
  - `SearchResult.swift`：
    > **注意**：spec 第 7.2 节声明 `SearchResult: Identifiable` 但字段名为 `fileID`，无法直接编译。本计划以"可编译 + 可对齐 spec 意图"为原则，加入计算属性 `var id: String { fileID }` 作为 `Identifiable` 的满足。其余字段严格按 spec 定义不变。
    ```swift
    struct SearchResult: Identifiable {
        let fileID: String
        var id: String { fileID }   // 满足 Identifiable；spec 7.2 未显式写出，此为最小侵入性修复
        let title: String?
        let snippet: String
        let score: Double
        let searchMode: SearchMode
        let tags: [String]
        let created: Date
    }
    enum SearchMode: String, Codable { case fulltext, semantic, hybrid }
    ```
  - `ChatMessage.swift`：
    ```swift
    struct ChatMessage: Identifiable, Codable {
        let id: UUID
        let role: ChatRole
        let content: String
        let timestamp: Date
        var isStreaming: Bool
        var citations: [Citation]
    }
    enum ChatRole: String, Codable { case user, assistant, system }
    struct Citation: Codable { let fileID: String; let title: String; let snippet: String }
    ```
  - `LLMConfig.swift`：struct LLMConfig，字段：`defaultProvider: String`、`model: String`、`maxTokens: Int`、`temperature: Double`
  - `VaultConfig.swift`：struct VaultConfig，字段：`vaultRootURL: URL`、`hybridAlpha: Double`（默认 0.4）

  **Must NOT do**:
  - **不把 Entry.id 改为 UUID**（spec 定义为 String）
  - 不添加 spec 未定义的 public 字段
  - 不使用 `@Observable`（Models 是纯值类型）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（Task 1 创建目录后立即开始）
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 3, 4, 5, 6
  - **Blocked By**: Task 1

  **References**:
  - `MyKnownTechSpec.md` 第 7 节（第 618 行起）— Entry（7.1）/ SearchResult（7.2）/ ChatMessage（7.3）**完整类型定义**

  **Acceptance Criteria**:
  - [ ] `swift build` 通过，所有 struct/enum 无编译错误
  - [ ] `Entry.id` 字段声明为 `String` 类型（可通过 grep 验证）

  ```
  Scenario: 数据模型编译通过
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift build 2>&1
    Expected Result: "Build complete!" 无 error
    Evidence: .sisyphus/evidence/task-2-build.txt

  Scenario: Entry.id 为 String 类型（grep 验证）
    Tool: Bash
    Steps:
      1. grep "let id: String" Sources/KnowledgeVaultCore/Models/Entry.swift
    Expected Result: 输出包含 "let id: String" 匹配行（行数 >= 1）
    Evidence: .sisyphus/evidence/task-2-entry-id.txt

  Scenario: EntrySource canonical 值正确（grep 验证）
    Tool: Bash
    Steps:
      1. grep "case manual, camera, share, clipboard" Sources/KnowledgeVaultCore/Models/Entry.swift
    Expected Result: 输出包含该行（第 7 节 canonical 值）
    Evidence: .sisyphus/evidence/task-2-entrysource.txt
  ```

  **Commit**: YES（与 Task 1 合并）

---

- [x] 3. KnowledgeVaultFileManager 协议 + 实现 + FrontmatterParser（Sources/KnowledgeVaultCore/FileManager/）

  **What to do**:
  - `KnowledgeVaultFileManager.swift`：**严格按 MyKnownTechSpec.md 5.1 节**实现协议：
    ```swift
    protocol KnowledgeVaultFileManager {
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
    enum VaultDirectory { case inbox, topics(String), archive }
    ```
  - `VaultFileManagerImpl.swift`：`actor VaultFileManagerImpl: KnowledgeVaultFileManager`，内部使用 NSFileCoordinator 读写
  - `FrontmatterParser.swift`：struct FrontmatterParser
    - `static func parse(markdown: String) -> (frontmatter: [String: String], body: String)` — `---` 分隔 YAML
    - `static func serialize(frontmatter: [String: String], body: String) -> String`
  - `MarkdownSerializer.swift`：`static func entryToMarkdown(_ entry: Entry) -> String` 和 `markdownToEntry(url: URL, content: String) throws -> Entry`
  - `createEntry` 生成 id 格式：`DateFormatter("yyyyMMdd-HHmmss") + "-" + UUID().uuidString.prefix(4).lowercased()`
  - `.index/` 目录创建时设置 `URLResourceValues.isExcludedFromBackup = true`

  **Must NOT do**:
  - 不直接用 `FileManager.default`（必须通过 NSFileCoordinator）
  - 不引入第三方 YAML 库
  - **不改变 readEntry(id: String) 的参数类型**

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 4, 5, 6 并行）
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 7, 8
  - **Blocked By**: Task 1, 2

  **References**:
  - `MyKnownTechSpec.md` 第 5.1 节（第 295~333 行）— KnowledgeVaultFileManager 协议完整签名
  - `MyKnownTechSpec.md` 第 3.2 节（第 136 行起）— Markdown 文件 frontmatter 格式（title/tags/created/type/source/status 字段）
    > **⚠️ EntrySource 磁盘值冲突说明**：第 3.2 节（第 144 行）用 `camera-roll / share-extension / clipboard`（带连字符），第 7 节（第 628 行）用 `camera / share / clipboard`（不带连字符）。**本计划以第 7 节为 canonical**（即 enum rawValue 为 `camera/share/clipboard`）。FrontmatterParser 在解析 frontmatter 时须做别名映射：读到 `camera-roll` → 转换为 `.camera`，读到 `share-extension` → 转换为 `.share`，其他值直接 rawValue 匹配。序列化时始终写出第 7 节的 canonical 值。
  - Apple NSFileCoordinator 文档：`https://developer.apple.com/documentation/foundation/nsfilecoordinator`
  - `URLResourceValues.isExcludedFromBackup`：`https://developer.apple.com/documentation/foundation/urlresourcevalues/1779579-isexcludedfrombackup`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `FrontmatterParser` 中存在 `parse` 静态方法（grep 验证）
  - [ ] `.index/` 目录创建代码中有 `isExcludedFromBackup` 设置（grep 验证）

  ```
  Scenario: FrontmatterParser 方法存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "static func parse" Sources/KnowledgeVaultCore/FileManager/FrontmatterParser.swift
    Expected Result: 输出包含 "static func parse" 匹配行
    Evidence: .sisyphus/evidence/task-3-frontmatter.txt

  Scenario: isExcludedFromBackup 代码存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "isExcludedFromBackup" Sources/KnowledgeVaultCore/FileManager/VaultFileManagerImpl.swift
    Expected Result: 输出包含 "isExcludedFromBackup" 匹配行（行数 >= 1）
    Evidence: .sisyphus/evidence/task-3-backup-flag.txt

  Scenario: EntrySource 别名映射代码存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "camera-roll\|share-extension" Sources/KnowledgeVaultCore/FileManager/FrontmatterParser.swift
    Expected Result: 输出包含映射逻辑所在行
    Evidence: .sisyphus/evidence/task-3-alias.txt
  ```

  **Commit**: YES（与 Task 4, 5, 6 合并）
  - Message: `feat(core): implement FileManager, LLM, Embedding module skeletons`

- [x] 4. SQLite Schema + GRDB DatabaseManager（Sources/KnowledgeVaultCore/Storage/）

  **What to do**:
  - `schema.sql`：完整 DDL，**Entry.id 为 TEXT 类型**（与 spec 第 7 节一致）：
    ```sql
    CREATE TABLE entries (
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
    CREATE TABLE embeddings (
      entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
      provider TEXT NOT NULL,
      dimensions INTEGER NOT NULL,
      vector BLOB NOT NULL,
      PRIMARY KEY (entry_id, provider)
    );
    CREATE VIRTUAL TABLE entries_fts USING fts5(
      title, content,
      content='entries', content_rowid='rowid',
      tokenize='unicode61'
    );
    CREATE TRIGGER entries_ai AFTER INSERT ON entries BEGIN
      INSERT INTO entries_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
    END;
    CREATE TRIGGER entries_au AFTER UPDATE ON entries BEGIN
      INSERT INTO entries_fts(entries_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.content);
      INSERT INTO entries_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
    END;
    CREATE TRIGGER entries_ad AFTER DELETE ON entries BEGIN
      INSERT INTO entries_fts(entries_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.content);
    END;
    ```
  - `DatabaseManager.swift`：`actor DatabaseManager`，方法：
    - `init(dbURL: URL) async throws` — DatabasePool，首次执行 schema migration
    - `func insertEntry(_ entry: Entry) async throws`
    - `func updateEntry(_ entry: Entry) async throws`
    - `func deleteEntry(id: String) async throws`
    - `func fetchEntry(id: String) async throws -> Entry?`
    - `func ftsSearch(query: String, limit: Int) async throws -> [(Entry, Double)]` — BM25 分数取绝对值
    - `func saveEmbedding(entryID: String, provider: String, dimensions: Int, vector: [Float]) async throws`
    - `func fetchEmbeddings(provider: String) async throws -> [(entryID: String, vector: [Float])]`
  - 向量 BLOB 编解码：`[Float]` ↔ `Data`（`withUnsafeBytes` 模式）

  **Must NOT do**:
  - **Entry 表 id 列不能用 INTEGER**（必须 TEXT）
  - 不把向量存为 JSON 字符串

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 3, 5, 6 并行）
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 7
  - **Blocked By**: Task 1, 2

  **References**:
  - `MyKnownTechSpec.md` 第 7.1 节（第 620~637 行）— Entry 字段定义（确认字段名对应关系）
  - GRDB DatabasePool 文档：`https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool`
  - GRDB FTS5 文档：`https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/fulltextsearch`
  - SQLite FTS5 外部内容表：`https://www.sqlite.org/fts5.html#external_content_tables`
  - SQLite FTS5 BM25（负值）：`https://www.sqlite.org/fts5.html#the_bm25_function`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `schema.sql` 中 `entries.id` 列类型为 TEXT（grep 验证）
  - [ ] FTS5 外部内容表及触发器定义存在（grep 验证）

  ```
  Scenario: entries.id 为 TEXT 类型（grep 验证）
    Tool: Bash
    Steps:
      1. grep "id TEXT PRIMARY KEY" Sources/KnowledgeVaultCore/Storage/schema.sql
    Expected Result: 输出包含 "id TEXT PRIMARY KEY" 匹配行
    Evidence: .sisyphus/evidence/task-4-fts.txt

  Scenario: FTS5 外部内容表及触发器存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "fts5" Sources/KnowledgeVaultCore/Storage/schema.sql
      2. grep "AFTER INSERT ON entries" Sources/KnowledgeVaultCore/Storage/schema.sql
    Expected Result: 步骤 1 输出包含 "fts5"；步骤 2 输出包含触发器定义行
    Evidence: .sisyphus/evidence/task-4-triggers.txt

  Scenario: 向量 BLOB 编解码方法存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "withUnsafeBytes\|withUnsafeMutableBytes" Sources/KnowledgeVaultCore/Storage/DatabaseManager.swift
    Expected Result: 输出包含 BLOB 编解码相关行
    Evidence: .sisyphus/evidence/task-4-blob.txt
  ```

  **Commit**: YES（与 Task 3, 5, 6 合并）

- [x] 5. LLMProvider 协议 + LLMAgent + 四个 Provider + SSEParser（Sources/KnowledgeVaultCore/LLM/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 5.2 节实现：
  - `LLMProvider.swift`：
    ```swift
    protocol LLMProvider {
        var name: String { get }
        var baseURL: URL { get }
        var apiKey: String { get }
        func chatCompletion(messages: [ChatMessage], model: String, temperature: Double) async throws -> AsyncStream<String>
        func embedding(text: String, model: String) async throws -> [Float]
    }
    ```
  - `LLMAgent.swift`：
    ```swift
    actor LLMAgent {
        private var config: LLMConfig
        private var providers: [String: LLMProvider]
        func chat(messages: [ChatMessage]) async throws -> AsyncStream<String>
        func embed(text: String) async throws -> [Float]
        func organizeEntries(entries: [Entry]) async throws -> [OrganizationResult]
        func answer(question: String, context: [String]) async throws -> AsyncStream<String>
        func setDefaultProvider(_ name: String)
        func fallbackChat(messages: [ChatMessage]) async throws -> AsyncStream<String>
    }
    struct OrganizationResult: Codable { let entryID: String; let suggestedTitle: String; let suggestedTags: [String]; let suggestedTopic: String }
    ```
  - `OpenAIProvider.swift`：实现 LLMProvider，endpoint `https://api.openai.com/v1/chat/completions`，`Authorization: Bearer {apiKey}` 头
  - `QwenProvider.swift`：实现 LLMProvider，endpoint `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
  - `AnthropicProvider.swift`：实现 LLMProvider，**独立 `system` 字段**，`anthropic-version: 2023-06-01` header，`x-api-key` 认证
  - `CustomProvider.swift`：实现 LLMProvider，**允许用户自定义 `baseURL` 和 `apiKey`**，endpoint 拼接规则：`baseURL.appendingPathComponent("chat/completions")`，请求格式兼容 OpenAI-compatible API（`Authorization: Bearer {apiKey}` 头），骨架实现与其他 Provider 同等处理
  - `SSEParser.swift`：`actor SSEParser`，解析 `data: {...}\n\n`，提取 delta.content，支持 `[DONE]` 终止
  - `KeychainManager.swift`：
    - `static func apiKey(for provider: String) throws -> String`，key 格式 `com.knowledgevault.apikey.{provider}`，属性 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
    - `static func saveAPIKey(for provider: String, key: String) throws`（Task 16 LLMConfigView 保存 API Key 时调用）

  **Must NOT do**:
  - 不用 Alamofire 或 Combine
  - **AnthropicProvider 不能把 system message 放入 messages 数组**
  - 不把 chatCompletion 改为非流式返回

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 3, 4, 6 并行）
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 9
  - **Blocked By**: Task 1, 2

  **References**:
  - `MyKnownTechSpec.md` 第 5.2 节（第 334~389 行）— LLMProvider 协议 + LLMAgent actor **完整签名**
  - Anthropic Messages API 独立 system 字段：`https://docs.anthropic.com/en/api/messages`（`system` 为顶层字段）
  - OpenAI Chat Completions API：`https://platform.openai.com/docs/api-reference/chat`
  - URLSession.bytes 文档：`https://developer.apple.com/documentation/foundation/urlsession/3767352-bytes`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] 四个 Provider 文件均存在（ls 验证）
  - [ ] AnthropicProvider 中不含把 system 放入 messages 的代码模式（grep 验证）
  - [ ] SSEParser 中有 `AsyncThrowingStream` 使用（grep 验证）

  ```
  Scenario: 四个 Provider 文件均存在（ls 验证）
    Tool: Bash
    Steps:
      1. ls Sources/KnowledgeVaultCore/LLM/
    Expected Result: 输出包含 OpenAIProvider.swift、QwenProvider.swift、AnthropicProvider.swift、CustomProvider.swift（4 个文件）
    Evidence: .sisyphus/evidence/task-5-providers.txt

  Scenario: AnthropicProvider 独立 system 字段（grep 验证）
    Tool: Bash
    Steps:
      1. grep '"system"' Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift
    Expected Result: 输出包含顶层 system 字段的赋值行（不应出现在 messages 数组内）
    Evidence: .sisyphus/evidence/task-5-anthropic.txt

  Scenario: SSEParser 使用 AsyncThrowingStream（grep 验证）
    Tool: Bash
    Steps:
      1. grep "AsyncThrowingStream" Sources/KnowledgeVaultCore/LLM/SSEParser.swift
    Expected Result: 输出包含 "AsyncThrowingStream" 匹配行（行数 >= 1）
    Evidence: .sisyphus/evidence/task-5-sse.txt
  ```

  **Commit**: YES（与 Task 3, 4, 6 合并）

- [x] 6. EmbeddingEngine actor + 余弦相似度（Sources/KnowledgeVaultCore/Embedding/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 5.4 节实现（骨架）：
    ```swift
    actor EmbeddingEngine {
        private var index: EmbeddingIndex      // 内部类型，暂时用 [String: [Float]] 表示
        func generateEmbedding(for fileID: String) async throws
        func batchGenerate(for fileIDs: [String]) async throws
        func semanticSearch(query: String, topK: Int) async throws -> [FileSimilarity]
        func needsUpdate(fileID: String) async -> Bool
        func incrementalUpdate() async throws
    }
    struct FileSimilarity { let fileID: String; let score: Float }
    ```
  - **补充实现**（spec 未覆盖的算法细节）：
    - `func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float` — 使用 Accelerate `vDSP_dotpr` + `vDSP_svesq`
    - `func rankBySimilarity(query: [Float], candidates: [(String, [Float])]) -> [(String, Float)]` — 降序排序
  - Phase 1：`generateEmbedding` / `batchGenerate` / `incrementalUpdate` 方法体可为 `throw EmbeddingError.notImplementedInPhase1`

  **Must NOT do**:
  - 不用手写 SIMD（使用 Accelerate 框架）
  - Phase 1 不实现真实 embedding 网络请求（只建骨架）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 3, 4, 5 并行）
  - **Parallel Group**: Wave 2
  - **Blocks**: Phase 2 语义搜索
  - **Blocked By**: Task 1, 2

  **References**:
  - `MyKnownTechSpec.md` 第 5.4 节（第 422~449 行）— EmbeddingEngine actor 完整签名
  - Accelerate vDSP 文档：`https://developer.apple.com/documentation/accelerate/vdsp`（重点：`vDSP_dotpr`、`vDSP_svesq`）
  - OpenAI Embeddings API：`https://platform.openai.com/docs/api-reference/embeddings`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `cosineSimilarity` 函数存在（grep 验证）
  - [ ] Accelerate `vDSP_dotpr` 使用（grep 验证）

  ```
  Scenario: 余弦相似度函数存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func cosineSimilarity" Sources/KnowledgeVaultCore/Embedding/EmbeddingEngine.swift
    Expected Result: 输出包含 "func cosineSimilarity" 匹配行
    Evidence: .sisyphus/evidence/task-6-cosine.txt

  Scenario: 使用 Accelerate vDSP（grep 验证）
    Tool: Bash
    Steps:
      1. grep "vDSP_dotpr\|vDSP_svesq" Sources/KnowledgeVaultCore/Embedding/EmbeddingEngine.swift
    Expected Result: 输出包含 vDSP 函数调用行（行数 >= 2）
    Evidence: .sisyphus/evidence/task-6-vdsp.txt

  Scenario: EmbeddingEngine 编译无错误
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift build 2>&1 | grep -c "error:" || true
    Expected Result: 输出 "0"
    Evidence: .sisyphus/evidence/task-6-build.txt
  ```

  **Commit**: YES（与 Task 3, 4, 5 合并）

---

- [x] 7. SearchEngine 协议 + SearchEngineImpl（Sources/KnowledgeVaultCore/Search/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 5.3 节实现协议：
    ```swift
    protocol SearchEngine {
        func indexFile(_ file: MarkdownFile) async throws
        func updateIndex(fileID: String) async throws
        func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult]
        func rebuildIndex() async throws
    }
    struct MarkdownFile { let id: String; let title: String?; let content: String; let tags: [String] }
    ```
  - `SearchEngineImpl.swift`：`actor SearchEngineImpl: SearchEngine`，内部持有 DatabaseManager
    - `search` 根据 mode 分发：`.fulltext` → `DatabaseManager.ftsSearch`，`.hybrid` → FTS + 归一化 + 混合
    - `.semantic` Phase 1 暂时 throw `.notImplemented`
  - 混合搜索归一化（按 VaultConfig.hybridAlpha 读取权重，默认 0.4/0.6）：
    ```
    FTS 分数取绝对值 → min-max 归一化 × α
    语义分数（Phase 1 为 0）× β
    最终分数 = FTS 归一化分 × α + 语义分 × β
    ```
  - `private func minMaxNormalize(_ scores: [(String, Double)]) -> [(String, Double)]`

  **Must NOT do**:
  - Phase 1 不实现语义搜索（throw .notImplemented）
  - 不把 hybridAlpha 硬编码为常量（从 VaultConfig 参数读取）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 8 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 9
  - **Blocked By**: Task 3, 4

  **References**:
  - `MyKnownTechSpec.md` 第 5.3 节（第 390~421 行）— SearchEngine 协议完整签名 + 混合搜索公式（α=0.4, β=0.6）
  - SQLite FTS5 BM25 负值说明：`https://www.sqlite.org/fts5.html#the_bm25_function`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `SearchEngine` 协议含 `search(query:mode:limit:)` 方法（grep 验证）
  - [ ] `minMaxNormalize` 私有方法存在（grep 验证）

  ```
  Scenario: SearchEngine 协议方法存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func search(query: String, mode: SearchMode, limit: Int)" Sources/KnowledgeVaultCore/Search/SearchEngine.swift
    Expected Result: 输出包含该签名行
    Evidence: .sisyphus/evidence/task-7-normalize.txt

  Scenario: minMaxNormalize 方法存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func minMaxNormalize" Sources/KnowledgeVaultCore/Search/SearchEngineImpl.swift
    Expected Result: 输出包含 "func minMaxNormalize" 匹配行
    Evidence: .sisyphus/evidence/task-7-search.txt

  Scenario: hybrid 搜索 alpha/beta 权重从 VaultConfig 读取（grep 验证）
    Tool: Bash
    Steps:
      1. grep "hybridAlpha" Sources/KnowledgeVaultCore/Search/SearchEngineImpl.swift
    Expected Result: 输出包含 "hybridAlpha" 使用行（不是硬编码 0.4）
    Evidence: .sisyphus/evidence/task-7-hybrid.txt
  ```

  **Commit**: YES（与 Task 8, 9 合并）
  - Message: `feat(core): implement Search, Sync, RAG module skeletons`

- [x] 8. SyncManager + ConflictResolver + VaultDirectoryPresenter（Sources/KnowledgeVaultCore/Sync/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 5.6 节实现：
    ```swift
    actor SyncManager {
        func enableICloud() async throws
        func disableICloud() async throws   // Task 16 LLMConfigView 需要调用此方法
        func syncStatus() async -> SyncStatus
        func handleConflict(local: File, remote: File) async -> ConflictResolution
        func syncNow() async throws
    }
    enum SyncStatus { case idle, syncing, error(Error), disabled }
    enum ConflictResolution { case useLocal, useRemote, merge(Entry) }
    struct File { let entry: Entry; let modifiedAt: Date }
    ```
  - `VaultDirectoryPresenter.swift`：`class VaultDirectoryPresenter: NSObject, NSFilePresenter`
    - `var presentedItemURL: URL?`
    - `func presentedItemDidChange()` — 通过 NotificationCenter 广播
    - `func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void)` — 调用 completionHandler(nil)
  - `ConflictResolver.swift`：struct ConflictResolver
    - `static func resolve(local: File, remote: File) -> ConflictResolution` — 策略：modifiedAt 较新者胜，相同时 remote 优先，保存副本（文件名加 `.conflict` 后缀）
  - `SyncManager` 内部注册/反注册 `VaultDirectoryPresenter`，`handleConflict` 委托给 `ConflictResolver`

  **Must NOT do**:
  - 不直接监听 NSMetadataQuery（用 NSFilePresenter）
  - Phase 1 只实现 last-write-wins，不实现完整三路合并

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 7 并行）
  - **Parallel Group**: Wave 3
  - **Blocks**: 无（独立模块）
  - **Blocked By**: Task 3

  **References**:
  - `MyKnownTechSpec.md` 第 5.6 节（第 490~514 行）— SyncManager actor 完整签名 + iCloud 实现方案
  - NSFilePresenter 协议文档：`https://developer.apple.com/documentation/foundation/nsfilepresenter`

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `SyncManager.handleConflict(local:remote:)` 方法签名存在（grep 验证）
  - [ ] `ConflictResolver.resolve` 静态方法存在（grep 验证）

  ```
  Scenario: handleConflict 方法签名存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func handleConflict(local: File, remote: File)" Sources/KnowledgeVaultCore/Sync/SyncManager.swift
    Expected Result: 输出包含该签名行
    Evidence: .sisyphus/evidence/task-8-conflict.txt

  Scenario: ConflictResolver.resolve 方法存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "static func resolve" Sources/KnowledgeVaultCore/Sync/ConflictResolver.swift
    Expected Result: 输出包含 "static func resolve" 匹配行
    Evidence: .sisyphus/evidence/task-8-resolver.txt

  Scenario: File struct 含 modifiedAt: Date 字段（grep 验证）
    Tool: Bash
    Steps:
      1. grep "let modifiedAt: Date" Sources/KnowledgeVaultCore/Sync/SyncManager.swift
    Expected Result: 输出包含 "let modifiedAt: Date" 匹配行
    Evidence: .sisyphus/evidence/task-8-file-struct.txt
  ```

  **Commit**: YES（与 Task 7, 9 合并）

- [x] 9. RAGPipeline + PromptBuilder（Sources/KnowledgeVaultCore/RAG/）

  **What to do**:
  - 严格按 MyKnownTechSpec.md 第 5.5 节实现：
    ```swift
    struct RAGPipeline {
        let searchEngine: SearchEngine
        let llmAgent: LLMAgent
        let fileManager: KnowledgeVaultFileManager
        func query(question: String, options: RAGOptions) async throws -> AsyncStream<String>
    }
    struct RAGOptions { var topK: Int = 5; var mode: SearchMode = .hybrid; var maxContextTokens: Int = 8000 }
    ```
  - `query` 内部流程严格按 spec 第 5.5 节：搜索 → 加载 Entry → buildSystemPrompt → LLMAgent.chat
  - `PromptBuilder.swift`：struct PromptBuilder（**spec 未定义，本计划补充**）
    - `static func buildSystemPrompt(contexts: [ContextSnippet]) -> String`
    - `static func estimateTokens(_ text: String) -> Int`（`text.count / 4`）
    - `static func truncateContexts(_ contexts: [ContextSnippet], maxTokens: Int) -> [ContextSnippet]` — 按 token 预算截断
    - `struct ContextSnippet { let fileID: String; let title: String?; let path: String; let content: String }`

  **Must NOT do**:
  - 不在 RAGPipeline 内部持久化对话历史（只接受传入 options）
  - token 估算不需要精确（/ 4 即可）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO（需要 Task 5 + 7 完成）
  - **Parallel Group**: Wave 3（最后完成）
  - **Blocks**: Task 10
  - **Blocked By**: Task 5, 7

  **References**:
  - `MyKnownTechSpec.md` 第 5.5 节（第 450~489 行）— RAGPipeline 完整实现逻辑（含 ContextSnippet 构造）
  - `MyKnownTechSpec.md` 第 8.2 节（第 705 行起）— RAG 问答 Prompt 模板

  **Acceptance Criteria**:
  - [ ] `swift build` 通过
  - [ ] `RAGPipeline.query(question:options:)` 方法签名存在（grep 验证）
  - [ ] `PromptBuilder.estimateTokens` 方法存在（grep 验证）
  - [ ] `RAGOptions` 中 `maxContextTokens` 默认值为 8000（grep 验证）

  ```
  Scenario: RAGPipeline.query 签名存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func query(question: String, options: RAGOptions)" Sources/KnowledgeVaultCore/RAG/RAGPipeline.swift
    Expected Result: 输出包含该签名行
    Evidence: .sisyphus/evidence/task-9-truncation.txt

  Scenario: PromptBuilder.estimateTokens 存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "func estimateTokens" Sources/KnowledgeVaultCore/RAG/PromptBuilder.swift
    Expected Result: 输出包含 "func estimateTokens" 匹配行
    Evidence: .sisyphus/evidence/task-9-tokens.txt

  Scenario: RAGOptions.maxContextTokens 默认值 8000（grep 验证）
    Tool: Bash
    Steps:
      1. grep "maxContextTokens.*8000\|8000.*maxContextTokens" Sources/KnowledgeVaultCore/RAG/RAGPipeline.swift
    Expected Result: 输出包含默认值赋值行
    Evidence: .sisyphus/evidence/task-9-build.txt
  ```

  **Commit**: YES（与 Task 7, 8 合并）

---

- [x] 10. 所有模块单元测试（Tests/KnowledgeVaultCoreTests/）

  **What to do**:
  - 为 Task 3~9 的每个模块创建对应测试文件（7 个 .swift 文件），**每个测试文件的测试函数名须与本计划 QA 场景设计一一对应**：
  - `FrontmatterParserTests.swift`（对应 Task 3 行为）：
    - `testFrontmatterParseTitleAndTags` — 标准 frontmatter 解析
    - `testFrontmatterParseEntrySourceAliasMapping` — `camera-roll` → `.camera`，`share-extension` → `.share`
    - `testFrontmatterRoundtrip` — parse + serialize 往返一致
  - `DatabaseManagerTests.swift`（对应 Task 4 行为）：
    - `testEntryIDIsTextColumn` — schema 中 `id TEXT` 验证（内存 DB）
    - `testFTSInsertAndSearch` — 插入 entry 后 FTS 能搜索到
    - `testEmbeddingBlobRoundtrip` — `[Float]` ↔ `Data` 编解码往返
    - `testDeleteCascadesEmbedding` — 删除 entry 时 embeddings 级联删除
  - `SSEParserTests.swift`（对应 Task 5 行为）：
    - `testSSEParserDeltaExtraction` — 标准 delta.content 提取
    - `testSSEParserDoneTerminates` — `[DONE]` 使 stream 正常结束
    - `testSSEParserEmptyData` — 空 data 行不崩溃
    - `testSSEParserMultipleDeltas` — 多 delta 合并成完整字符串
  - `CosineSimilarityTests.swift`（对应 Task 6 行为）：
    - `testCosineSimilaritySameVector` — 相同向量 ≈ 1.0（误差 < 1e-6）
    - `testCosineSimilarityOrthogonal` — 正交向量 ≈ 0.0（误差 < 1e-6）
    - `testCosineSimilarityZeroVector` — 零向量不 crash（返回 0 或 throw）
  - `SearchEngineTests.swift`（对应 Task 7 行为）：
    - `testMinMaxNormalize` — `[(id1, 3.0), (id2, 1.0)]` → `[(id1, 1.0), (id2, 0.0)]`
    - `testSearchEngineFTSMode` — 索引 2 条 Entry，搜索能匹配 1 条
    - `testHybridAlphaFromConfig` — hybridAlpha 从 VaultConfig 读取（非硬编码）
  - `ConflictResolverTests.swift`（对应 Task 8 行为）：
    - `testConflictResolverNewerWins` — `remote.modifiedAt` 较新时返回 `.useRemote`
    - `testConflictResolverLocalWins` — `local.modifiedAt` 较新时返回 `.useLocal`
    - `testConflictResolverSameTimestampUsesRemote` — 相同时间戳 remote 优先
  - `PromptBuilderTests.swift`（对应 Task 9 行为）：
    - `testEstimateTokensBasic` — `"Hello World"` → `2`（11 / 4 取整）
    - `testPromptBuilderTokenTruncation` — 超出预算时 contexts 数量减少
    - `testBuildSystemPromptNotEmpty` — buildSystemPrompt 返回非空字符串
  - 使用 Swift Testing（`import Testing`，`@Test`，`#expect`）
  - 总 `@Test` 函数数 ≥ 22（以上已规划 23 个）

  **Must NOT do**:
  - 不使用 XCTest
  - 不写超出测试范围的生产代码

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Final Verification
  - **Blocked By**: Task 3~9

  **References**:
  - Swift Testing 框架文档：`https://developer.apple.com/documentation/testing`
  - Task 3~9 各自的 QA Scenarios — 直接作为测试用例来源

  **Acceptance Criteria**:
  - [ ] `swift test` 输出 `All tests passed`（或 `Test Suite... passed`）
  - [ ] `swift test --list-tests 2>&1 | wc -l` 输出 ≥ 22

  ```
  Scenario: 全量测试通过
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift test 2>&1
    Expected Result: 所有测试通过，失败数 = 0
    Evidence: .sisyphus/evidence/task-10-test-output.txt

  Scenario: 测试数量满足要求
    Tool: Bash
    Steps:
      1. swift test --list-tests 2>&1 | wc -l
    Expected Result: 行数 >= 22
    Evidence: .sisyphus/evidence/task-10-test-count.txt
  ```

  **Commit**: YES
  - Message: `test(core): add unit tests for all KnowledgeVaultCore modules`
  - Pre-commit: `swift test`

---

- [x] 11. iOS App Target 创建 + App 入口 + 共享 UI 组件（KnowledgeVault-iOS/）

  **What to do**:
  - **创建 Xcode 项目和 iOS App Target**（这是 Task 12~16 的编译前提）：
    - 使用 `xcodegen`（如已安装）或手动创建 `KnowledgeVault.xcodeproj`，App Target 名 `KnowledgeVaultApp`，Bundle ID `com.knowledgevault.app`，Deployment Target iOS 17.0
    - 若本机无 xcodegen，用 `swift package init --type executable` 创建可编译占位，待后续在 Xcode GUI 中补全；**无论哪种方式，`KnowledgeVault-iOS/` 目录必须物理存在**
    - 在 `KnowledgeVault-iOS/` 下创建完整目录结构：`Features/Inbox/`、`Features/Browse/`、`Features/Search/`、`Features/Chat/`、`Features/Settings/`、`Components/`、`Extensions/`、`Resources/`
    - 创建 `Resources/Assets.xcassets`（空 xcassets）和 `Resources/Localizable.xcstrings`（空 strings 文件）
  - **App 入口文件**：
    - `KnowledgeVaultApp.swift`：`@main struct KnowledgeVaultApp: App`，在 `.environment` 注入共享依赖（`VaultFileManagerImpl`、`DatabaseManager`、`LLMAgent`），使用 `@Observable` 包装的 `AppState` 管理全局状态（当前 tab、vault 初始化状态）；根视图为 `TabView`，含 5 个 Tab（Inbox / Browse / Search / Chat / Settings），使用 `.tabItem { Label(...) }`
    - `AppDelegate.swift`：仅处理 `UIApplicationDelegate` 必要方法（`application(_:didFinishLaunchingWithOptions:)`），不做业务逻辑
  - **共享组件** `Components/`：
    - `MarkdownRenderer.swift`：基于 `AttributedString` 渲染 Markdown，支持标题/加粗/代码块/链接；`struct MarkdownRenderer: View`，接受 `content: String`
    - `ShareSheet.swift`：`struct ShareSheet: UIViewControllerRepresentable`，包装 `UIActivityViewController`
    - `DocumentPicker.swift`：`struct DocumentPicker: UIViewControllerRepresentable`，包装 `UIDocumentPickerViewController`，回调返回选中的 `URL`
    - `CameraCapture.swift`：`struct CameraCapture: UIViewControllerRepresentable`，包装 `UIImagePickerController`（`.camera` sourceType），回调返回 `UIImage`

  **Must NOT do**:
  - 不引入 Markdown 渲染三方库（用 `AttributedString` 实现基础渲染）
  - `AppDelegate` 不持有业务逻辑，不存储任何 ViewModel
  - 不在 App 入口做同步文件 IO

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO（先于所有 Feature 模块，建立依赖基础）
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 12, 13, 14, 15, 16
  - **Blocked By**: Task 10

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 567~614 行）— iOS App 目录结构
  - `MyKnownTechSpec.md` 第 2.1 节（第 39~92 行）— 整体架构图，4 Tab 导航结构
  - SwiftUI App lifecycle：`https://developer.apple.com/documentation/swiftui/app`

  **Acceptance Criteria**:
  - [ ] `KnowledgeVault-iOS/` 目录及 5 个 Feature 子目录存在（ls 验证）
  - [ ] `TabView` 含 5 个 tabItem（grep 验证）
  - [ ] `MarkdownRenderer`、`ShareSheet`、`DocumentPicker`、`CameraCapture` 4 个文件存在（ls 验证）
  - [ ] `xcodebuild -project KnowledgeVault.xcodeproj -scheme KnowledgeVaultApp -destination "generic/platform=iOS Simulator" build` 通过（若 Xcode 项目已创建）；若使用占位方案则 `swift build` 通过

  ```
  Scenario: KnowledgeVault-iOS 目录结构完整（ls 验证）
    Tool: Bash
    Steps:
      1. ls KnowledgeVault-iOS/Features/
    Expected Result: 输出包含 Inbox Browse Search Chat Settings 5 个子目录
    Evidence: .sisyphus/evidence/task-11-dirs.txt

  Scenario: TabView 含 5 个 Tab（grep 验证）
    Tool: Bash
    Steps:
      1. grep -c "tabItem" KnowledgeVault-iOS/KnowledgeVaultApp.swift
    Expected Result: 输出 >= 5
    Evidence: .sisyphus/evidence/task-11-tabs.txt

  Scenario: 共享组件文件存在（ls 验证）
    Tool: Bash
    Steps:
      1. ls KnowledgeVault-iOS/Components/
    Expected Result: 输出包含 MarkdownRenderer.swift、ShareSheet.swift、DocumentPicker.swift、CameraCapture.swift
    Evidence: .sisyphus/evidence/task-11-components.txt
  ```

  **Commit**: YES（与 Task 12~16 合并）
  - Message: `feat(ios): add SwiftUI app scaffold and shared UI components`

- [ ] 12. Inbox 功能（Features/Inbox/）

  **What to do**:
  - `InboxViewModel.swift`：`@Observable final class InboxViewModel`
    - `var entries: [Entry] = []`
    - `var isLoading: Bool = false`
    - `var error: Error? = nil`
    - `func loadEntries() async` — 调用 `KnowledgeVaultFileManager.listEntries(in: .inbox)`
    - `func createEntry(content: String, type: EntryType, source: EntrySource) async throws` — 调用 `KnowledgeVaultFileManager.createEntry`，成功后刷新列表
    - `func deleteEntry(_ entry: Entry) async throws`
  - `InboxView.swift`：`struct InboxView: View`
    - `NavigationStack` + `List` 展示 `entries`
    - 每行显示：`entry.title ?? "无标题"`、`entry.type` 图标、`entry.created` 相对时间
    - 下拉刷新（`.refreshable`）
    - 右上角 `+` 按钮弹出 `CreateEntryView`（`.sheet`）
    - 左滑删除（`.onDelete`）
    - `.task { await viewModel.loadEntries() }` 初始加载
  - `CreateEntryView.swift`：`struct CreateEntryView: View`
    - `TextEditor` 输入内容
    - `Picker` 选择 `EntryType`（note/screenshot/voice/link/file）
    - `Picker` 选择 `EntrySource`（manual/camera/share/clipboard）
    - 相机按钮触发 `CameraCapture`
    - 文件选择按钮触发 `DocumentPicker`
    - 保存按钮调用 `InboxViewModel.createEntry`

  **Must NOT do**:
  - 不在 View 内直接调用 Core API（通过 ViewModel 中转）
  - 不使用 `@StateObject`（iOS 17+ 使用 `@State` + `@Observable`）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 13, 14, 15, 16 并行）
  - **Parallel Group**: Wave 6
  - **Blocks**: 无
  - **Blocked By**: Task 11

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 573~576 行）— Inbox 文件列表
  - `MyKnownTechSpec.md` 第 5.1 节（第 295~333 行）— `listEntries`、`createEntry`、`deleteEntry` 签名
  - `MyKnownTechSpec.md` 第 7.1 节（第 620~637 行）— Entry 字段（用于列表展示）

  **Acceptance Criteria**:
  - [ ] `InboxView`、`InboxViewModel`、`CreateEntryView` 3 个文件存在
  - [ ] `InboxViewModel` 使用 `@Observable`（grep 验证）
  - [ ] `InboxView` 包含 `.refreshable`（grep 验证）

  ```
  Scenario: InboxViewModel 使用 @Observable（grep 验证）
    Tool: Bash
    Steps:
      1. grep "@Observable" KnowledgeVault-iOS/Features/Inbox/InboxViewModel.swift
    Expected Result: 输出包含 "@Observable" 行
    Evidence: .sisyphus/evidence/task-12-observable.txt

  Scenario: InboxView 含下拉刷新（grep 验证）
    Tool: Bash
    Steps:
      1. grep "refreshable" KnowledgeVault-iOS/Features/Inbox/InboxView.swift
    Expected Result: 输出包含 ".refreshable" 修饰符行
    Evidence: .sisyphus/evidence/task-12-refresh.txt
  ```

  **Commit**: YES（与 Task 11, 13~16 合并）

- [ ] 13. Browse + Topics + Entry 详情（Features/Browse/）

  **What to do**:
  - `BrowseView.swift`：`struct BrowseView: View`
    - `NavigationSplitView`（iPad）或 `NavigationStack`（iPhone）
    - 左侧/顶层：`TopicListView`，右侧/下级：`EntryDetailView`
    - `.toolbar` 含切换"按主题"/"按日期"的 `Picker`
  - `TopicListView.swift`：`struct TopicListView: View`
    - `List` 展示所有 topics（调用 `KnowledgeVaultFileManager.listEntries(in: .topics(""))` 聚合）
    - 每行显示 topic 名称 + 条目数量徽章
    - 点击 topic → 导航到该 topic 下的 Entry 列表
  - `DailyView.swift`：`struct DailyView: View`
    - 按 `entry.created` 日期分组，`Section` 展示每天的条目
    - 日期格式：`"yyyy年MM月dd日 EEEE"`
  - `EntryDetailView.swift`：`struct EntryDetailView: View`
    - 接受 `entry: Entry` 参数
    - 上方：`MarkdownRenderer(content: entry.content)`
    - 下方：tags 横向滚动 `ScrollView(.horizontal)`，`ForEach(entry.tags)`
    - `toolbar`：编辑按钮（进入编辑模式，`TextEditor` 替换 `MarkdownRenderer`）、分享按钮（触发 `ShareSheet`）
    - 编辑模式保存：调用 `KnowledgeVaultFileManager.updateEntry`

  **Must NOT do**:
  - 不在 View 里直接持有 `@Observable` ViewModel（直接用环境注入的 fileManager）
  - `DailyView` 不做服务端分页（Phase 1 全量加载）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 12, 14, 15, 16 并行）
  - **Parallel Group**: Wave 6
  - **Blocks**: 无
  - **Blocked By**: Task 11

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 578~582 行）— Browse 文件列表
  - `MyKnownTechSpec.md` 第 5.1 节 — `listEntries(in: .topics(String))`、`updateEntry` 签名

  **Acceptance Criteria**:
  - [ ] 4 个文件存在（ls 验证）
  - [ ] `EntryDetailView` 含 `MarkdownRenderer`（grep 验证）
  - [ ] `EntryDetailView` 含编辑模式（grep `TextEditor` 验证）

  ```
  Scenario: Browse 目录文件完整（ls 验证）
    Tool: Bash
    Steps:
      1. ls KnowledgeVault-iOS/Features/Browse/
    Expected Result: 输出包含 BrowseView.swift、TopicListView.swift、DailyView.swift、EntryDetailView.swift
    Evidence: .sisyphus/evidence/task-13-files.txt

  Scenario: EntryDetailView 集成 MarkdownRenderer（grep 验证）
    Tool: Bash
    Steps:
      1. grep "MarkdownRenderer" KnowledgeVault-iOS/Features/Browse/EntryDetailView.swift
    Expected Result: 输出包含 "MarkdownRenderer" 使用行
    Evidence: .sisyphus/evidence/task-13-markdown.txt
  ```

  **Commit**: YES（与 Task 11, 12, 14~16 合并）

- [ ] 14. 全文搜索界面（Features/Search/）

  **What to do**:
  - `SearchView.swift`：`struct SearchView: View`
    - `@State private var query: String = ""`
    - `@State private var results: [SearchResult] = []`
    - `@State private var searchMode: SearchMode = .hybrid`
    - `@State private var isSearching: Bool = false`
    - `searchable(text: $query)` 或手动 `TextField` + 搜索按钮
    - `Picker` 切换 SearchMode（全文 / 混合），`.segmentedPickerStyle`
    - 搜索结果用 `List` + `SearchResultRow` 渲染
    - `.onChange(of: query)` debounce 500ms（用 `Task.sleep` 实现）后触发搜索
    - 空状态：`ContentUnavailableView("暂无结果", systemImage: "magnifyingglass")`
    - 搜索调用：`KnowledgeVaultFileManager.search(query:mode:)`
  - `SearchResultRow.swift`：`struct SearchResultRow: View`
    - 显示：`result.title ?? result.fileID`（粗体）
    - `result.snippet`（灰色，最多 2 行，`.lineLimit(2)`）
    - `result.score` 格式化为百分比（`String(format: "%.0f%%", result.score * 100)`）
    - `result.tags` 横排小标签（`Capsule` 背景）

  **Must NOT do**:
  - 不在每次按键都立即触发网络/IO（必须 debounce）
  - 不显示 `result.fileID` 作为主标题（优先 `title`）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 12, 13, 15, 16 并行）
  - **Parallel Group**: Wave 6
  - **Blocks**: 无
  - **Blocked By**: Task 11

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 584~586 行）— Search 文件列表
  - `MyKnownTechSpec.md` 第 7.2 节（第 638~650 行）— SearchResult 字段定义

  **Acceptance Criteria**:
  - [ ] 2 个文件存在
  - [ ] debounce 逻辑存在（grep `Task.sleep` 验证）
  - [ ] `ContentUnavailableView` 用于空状态（grep 验证）

  ```
  Scenario: debounce 逻辑存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "Task.sleep\|debounce" KnowledgeVault-iOS/Features/Search/SearchView.swift
    Expected Result: 输出包含 Task.sleep 调用行
    Evidence: .sisyphus/evidence/task-14-debounce.txt

  Scenario: 空状态视图存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "ContentUnavailableView" KnowledgeVault-iOS/Features/Search/SearchView.swift
    Expected Result: 输出包含 "ContentUnavailableView" 行
    Evidence: .sisyphus/evidence/task-14-empty.txt
  ```

  **Commit**: YES（与 Task 11~13, 15, 16 合并）

- [ ] 15. AI 对话界面（Features/Chat/）

  **What to do**:
  - `ChatViewModel.swift`：`@Observable final class ChatViewModel`
    - `var messages: [ChatMessage] = []`
    - `var isStreaming: Bool = false`
    - `var currentStreamingContent: String = ""`
    - `func sendMessage(_ text: String) async throws` — 构造用户消息 → 调用 `RAGPipeline.query(question:options:)` → 收集 `AsyncStream<String>` 更新 `currentStreamingContent` → 流结束后追加完整 assistant 消息
    - `func clearHistory()`
  - `ChatView.swift`：`struct ChatView: View`
    - `ScrollViewReader` + `ScrollView` 展示消息列表，新消息自动滚动到底部（`.scrollTo(lastID, anchor: .bottom)`）
    - `ForEach(viewModel.messages)` → `ChatMessageBubble`
    - 流式输出中：在列表末尾追加临时气泡，内容为 `viewModel.currentStreamingContent`，显示光标动画（`@State var showCursor: Bool`，0.5s 闪烁）
    - 底部：`HStack` 含 `TextField("问点什么…", text: $input)` + 发送按钮（`viewModel.isStreaming` 时禁用）
    - `MarkdownRenderer` 渲染 assistant 消息内容
  - `ChatMessageBubble.swift`：`struct ChatMessageBubble: View`
    - user 消息：右对齐，蓝色气泡，白字
    - assistant 消息：左对齐，灰色气泡，`MarkdownRenderer` 渲染
    - 气泡最大宽度 `.frame(maxWidth: UIScreen.main.bounds.width * 0.75)`
    - 长按 → `.contextMenu` 含"复制"选项

  **Must NOT do**:
  - 不把流式 token 逐个追加到 `messages` 数组（用 `currentStreamingContent` 临时缓冲）
  - 不在 View 直接持有 `RAGPipeline`（通过 `ChatViewModel` 中转）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 12, 13, 14, 16 并行）
  - **Parallel Group**: Wave 6
  - **Blocks**: 无
  - **Blocked By**: Task 11

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 588~591 行）— Chat 文件列表
  - `MyKnownTechSpec.md` 第 5.5 节（第 450~489 行）— `RAGPipeline.query` 返回 `AsyncStream<String>`
  - `MyKnownTechSpec.md` 第 7.3 节（第 651~670 行）— ChatMessage / ChatRole / Citation 定义

  **Acceptance Criteria**:
  - [ ] 3 个文件存在
  - [ ] `ChatViewModel` 使用 `@Observable`（grep 验证）
  - [ ] `currentStreamingContent` 流式缓冲字段存在（grep 验证）
  - [ ] `ScrollViewReader` 用于自动滚动（grep 验证）

  ```
  Scenario: ChatViewModel 流式缓冲字段存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "currentStreamingContent" KnowledgeVault-iOS/Features/Chat/ChatViewModel.swift
    Expected Result: 输出包含 "currentStreamingContent" 字段声明行
    Evidence: .sisyphus/evidence/task-15-streaming.txt

  Scenario: ChatView 自动滚动存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "ScrollViewReader\|scrollTo" KnowledgeVault-iOS/Features/Chat/ChatView.swift
    Expected Result: 输出包含 ScrollViewReader 或 scrollTo 使用行
    Evidence: .sisyphus/evidence/task-15-scroll.txt
  ```

  **Commit**: YES（与 Task 11~14, 16 合并）

- [ ] 16. 设置页（Features/Settings/）

  **What to do**:
  - `SettingsView.swift`：`struct SettingsView: View`
    - `Form` 包含多个 `Section`：
      - "LLM 配置" → `NavigationLink` 导航到 `LLMConfigView`
      - "同步设置" → `NavigationLink` 导航到 `SyncSettingsView`
      - "关于" Section：显示 App 版本（`Bundle.main.infoDictionary["CFBundleShortVersionString"]`）
  - `LLMConfigView.swift`：`struct LLMConfigView: View`
    - `Picker` 选择默认 Provider（openai / qwen / anthropic / custom）
    - `TextField` 输入对应 API Key（`.textContentType(.password)`，`.autocorrectionDisabled`）
    - "保存" 按钮：调用 `KeychainManager.saveAPIKey(for: provider, key: input)`
    - Custom Provider 时额外显示 `TextField` 输入 Base URL
    - 保存成功后 `LLMAgent.setDefaultProvider(name:)` 切换默认 provider
  - `SyncSettingsView.swift`：`struct SyncSettingsView: View`
    - `Toggle("启用 iCloud 同步", isOn: $iCloudEnabled)`：调用 `SyncManager.enableICloud()` / `SyncManager.disableICloud()`
    - 同步状态：`Text` 展示 `SyncManager.syncStatus()` 结果（idle/syncing/error/disabled）
    - "立即同步" 按钮：调用 `SyncManager.syncNow()`，`isLoading` 期间显示 `ProgressView`

  **Must NOT do**:
  - API Key 不能用 `@AppStorage` 或 `UserDefaults` 存储（必须走 Keychain）
  - 不在 Settings 里直接实例化 `DatabaseManager` 等重型对象

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES（与 Task 12, 13, 14, 15 并行）
  - **Parallel Group**: Wave 6
  - **Blocks**: 无
  - **Blocked By**: Task 11

  **References**:
  - `MyKnownTechSpec.md` 第 6 节（第 593~596 行）— Settings 文件列表
  - `MyKnownTechSpec.md` 第 5.2 节（第 507 行）— `KeychainManager` key 格式 `com.knowledgevault.apikey.{provider}`
  - `MyKnownTechSpec.md` 第 5.6 节（第 490~514 行）— `SyncManager.enableICloud`、`syncStatus`、`syncNow` 签名

  **Acceptance Criteria**:
  - [ ] 3 个文件存在
  - [ ] `LLMConfigView` 使用 `KeychainManager`（grep 验证，不含 `UserDefaults` 或 `AppStorage`）
  - [ ] `SyncSettingsView` 含 `Toggle`（grep 验证）

  ```
  Scenario: API Key 走 Keychain（grep 验证）
    Tool: Bash
    Steps:
      1. grep "KeychainManager" KnowledgeVault-iOS/Features/Settings/LLMConfigView.swift
      2. grep "UserDefaults\|AppStorage" KnowledgeVault-iOS/Features/Settings/LLMConfigView.swift || echo "NONE"
    Expected Result: 步骤 1 有输出；步骤 2 输出 "NONE"
    Evidence: .sisyphus/evidence/task-16-keychain.txt

  Scenario: iCloud 同步开关存在（grep 验证）
    Tool: Bash
    Steps:
      1. grep "Toggle" KnowledgeVault-iOS/Features/Settings/SyncSettingsView.swift
    Expected Result: 输出包含 "Toggle" 行
    Evidence: .sisyphus/evidence/task-16-toggle.txt
  ```

  **Commit**: YES（与 Task 11~15 合并）
  - Message: `feat(ios): implement all SwiftUI feature views (Inbox/Browse/Search/Chat/Settings)`

---

- [x] F1. **编译验证** — `quick`

  在 `Packages/KnowledgeVaultCore/` 目录运行 `swift build`，必须零错误零警告。

  ```
  Scenario: 全量编译无错误
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift build 2>&1
    Expected Result: 最后一行包含 "Build complete!"，grep -c "error:" 输出为 0
    Evidence: .sisyphus/evidence/final-build.txt
  ```

  输出格式：`Build complete! | Errors: 0 | Warnings: N | VERDICT: APPROVE/REJECT`

- [x] F2. **测试验证** — `quick`

  运行 `swift test`，所有测试必须通过，数量 ≥ 22。

  ```
  Scenario: 全量测试通过且数量达标
    Tool: Bash
    Steps:
      1. cd Packages/KnowledgeVaultCore && swift test 2>&1
      2. swift test --list-tests 2>&1 | wc -l
    Expected Result: 步骤 1 无 FAILED；步骤 2 输出 >= 22
    Evidence: .sisyphus/evidence/final-tests.txt
  ```

  输出格式：`Tests [N/N pass] | Count: N | VERDICT: APPROVE/REJECT`

- [x] F3. **接口一致性检查** — `oracle`

  逐项对照 MyKnownTechSpec.md 验证以下内容（每项用 `grep` 在源码中搜索签名）：

  **第 7 节数据模型**（第 618~670 行）：
  - [ ] `Entry.id` 类型为 `String`：`grep "let id: String" Sources/KnowledgeVaultCore/Models/Entry.swift`
  - [ ] `Entry.content` 字段存在：`grep "var content: String" Sources/KnowledgeVaultCore/Models/Entry.swift`
  - [ ] `Entry.relativePath` 字段存在：`grep "var relativePath: String" Sources/KnowledgeVaultCore/Models/Entry.swift`
  - [ ] `SearchResult.fileID` 类型为 `String`：`grep "let fileID: String" Sources/KnowledgeVaultCore/Models/SearchResult.swift`
  - [ ] `ChatMessage.isStreaming` 字段存在：`grep "var isStreaming: Bool" Sources/KnowledgeVaultCore/Models/ChatMessage.swift`

  **第 5.1 节 KnowledgeVaultFileManager**（第 295~333 行）：
  - [ ] `readEntry(id: String)` 方法签名：`grep "func readEntry(id: String)" Sources/KnowledgeVaultCore/FileManager/KnowledgeVaultFileManager.swift`
  - [ ] `listEntries(in directory: VaultDirectory)` 存在：`grep "func listEntries(in directory: VaultDirectory)" Sources/KnowledgeVaultCore/FileManager/KnowledgeVaultFileManager.swift`

  **第 5.2 节 LLMProvider/LLMAgent**（第 334~389 行）：
  - [ ] `chatCompletion(messages:model:temperature:)` 签名：`grep "func chatCompletion" Sources/KnowledgeVaultCore/LLM/LLMProvider.swift`
  - [ ] `LLMAgent.chat(messages:)` 返回 `AsyncStream<String>`：`grep "func chat(messages" Sources/KnowledgeVaultCore/LLM/LLMAgent.swift`
  - [ ] `LLMAgent.organizeEntries` 存在：`grep "func organizeEntries" Sources/KnowledgeVaultCore/LLM/LLMAgent.swift`

  **第 5.3 节 SearchEngine**（第 390~421 行）：
  - [ ] `search(query:mode:limit:)` 签名：`grep "func search(query: String, mode: SearchMode, limit: Int)" Sources/KnowledgeVaultCore/Search/SearchEngine.swift`

  **第 5.4 节 EmbeddingEngine**（第 422~449 行）：
  - [ ] `generateEmbedding(for fileID: String)` 存在：`grep "func generateEmbedding(for fileID: String)" Sources/KnowledgeVaultCore/Embedding/EmbeddingEngine.swift`
  - [ ] `semanticSearch(query:topK:)` 存在：`grep "func semanticSearch(query: String, topK: Int)" Sources/KnowledgeVaultCore/Embedding/EmbeddingEngine.swift`

  **第 5.5 节 RAGPipeline**（第 450~489 行）：
  - [ ] `query(question:options:)` 签名：`grep "func query(question: String, options: RAGOptions)" Sources/KnowledgeVaultCore/RAG/RAGPipeline.swift`

  **第 5.6 节 SyncManager**（第 490~514 行）：
  - [ ] `handleConflict(local:remote:)` 签名：`grep "func handleConflict(local: File, remote: File)" Sources/KnowledgeVaultCore/Sync/SyncManager.swift`
  - [ ] `syncStatus()` 存在：`grep "func syncStatus()" Sources/KnowledgeVaultCore/Sync/SyncManager.swift`

  通过标准：上述 16 项 grep 全部有输出（匹配 ≥ 1 行）。

  输出格式：`Interfaces [N/16 match] | Mismatches: [...] | VERDICT: APPROVE/REJECT`

- [x] F4. **iOS UI 层构建与文件完整性验证** — `quick`

  验证 Task 11~16 交付的 iOS UI 层是否完整且可编译：

  ```
  Scenario: KnowledgeVault-iOS 目录结构完整（ls 验证）
    Tool: Bash
    Steps:
      1. ls KnowledgeVault-iOS/Features/
      2. ls KnowledgeVault-iOS/Components/
    Expected Result:
      步骤1: Inbox Browse Search Chat Settings
      步骤2: MarkdownRenderer.swift ShareSheet.swift DocumentPicker.swift CameraCapture.swift
    Evidence: .sisyphus/evidence/final-ui-structure.txt

  Scenario: 17 个 SwiftUI 文件全部存在（find 验证）
    Tool: Bash
    Steps:
      1. find KnowledgeVault-iOS -name "*.swift" | wc -l
    Expected Result: 输出 >= 17
    Evidence: .sisyphus/evidence/final-ui-files.txt

  Scenario: @Observable ViewModel 正确使用（grep 验证，不含 @StateObject）
    Tool: Bash
    Steps:
      1. grep -r "@Observable" KnowledgeVault-iOS/Features/ | wc -l
      2. grep -r "@StateObject" KnowledgeVault-iOS/ | wc -l || echo "0"
    Expected Result: 步骤1 输出 >= 2（InboxViewModel + ChatViewModel）；步骤2 输出 0
    Evidence: .sisyphus/evidence/final-ui-observable.txt

  Scenario: iOS App 项目编译（xcodebuild，如 xcodeproj 存在）
    Tool: Bash
    Steps:
      1. ls KnowledgeVault.xcodeproj 2>/dev/null && xcodebuild -project KnowledgeVault.xcodeproj -scheme KnowledgeVaultApp -destination "generic/platform=iOS Simulator" build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5 || echo "xcodeproj not present – skip build"
    Expected Result: 输出 "BUILD SUCCEEDED" 或 "xcodeproj not present – skip build"
    Evidence: .sisyphus/evidence/final-ui-build.txt
  ```

  输出格式：`UI Files [N/17] | @Observable [N] | @StateObject [0] | Build [PASS/SKIP] | VERDICT: APPROVE/REJECT`

---

## Commit Strategy

- Task 1~2: `feat(core): init Swift Package with GRDB dependency and data models`
- Task 3~6: `feat(core): implement FileManager, LLM, Embedding module skeletons`
- Task 7~9: `feat(core): implement Search, Sync, RAG module skeletons`
- Task 10: `test(core): add unit tests for all KnowledgeVaultCore modules`
- Task 11~16: `feat(ios): implement SwiftUI app scaffold and all feature views`

---

## Success Criteria

```bash
cd Packages/KnowledgeVaultCore
swift build    # 期望: Build complete!
swift test     # 期望: All tests passed（≥22 个）

# iOS UI 层
find KnowledgeVault-iOS -name "*.swift" | wc -l   # 期望: >= 17
grep -r "@Observable" KnowledgeVault-iOS/Features/ | wc -l  # 期望: >= 2
grep -r "@StateObject" KnowledgeVault-iOS/ | wc -l  # 期望: 0
```

### Final Checklist
- [ ] `swift build` 零错误
- [ ] `swift test` 全通过（≥22 个）
- [ ] 所有 Protocol/Actor 签名与 MyKnownTechSpec.md 第 5 节和第 7 节一致（16 项 grep 全匹配）
- [ ] 无 Combine/CoreData/Alamofire 引用
- [ ] `.index/` 目录创建时设置 `isExcludedFromBackup = true`
- [ ] `KnowledgeVault-iOS/` 下 ≥17 个 SwiftUI 文件，无 `@StateObject` 使用
- [ ] `SyncManager` 含 `disableICloud()` 方法，`KeychainManager` 含 `saveAPIKey(for:key:)` 方法
