# Bug Fix: SSEParser Anthropic 格式兼容 + AnthropicProvider Embedding 错误修复

## TL;DR

> **Quick Summary**: 修复两个已知 bug：①SSEParser 未处理 Anthropic 流式 SSE 格式导致 token 全丢弃；②AnthropicProvider.embedding 调用不存在的 Anthropic embedding 端点。
>
> **Deliverables**:
> - `SSEParser.swift`：`extractContent` 新增 `content_block_delta` 分支
> - `AnthropicProvider.swift`：`embedding` 方法改为立即抛出 `notSupported` 错误
>
> **Estimated Effort**: Quick
> **Parallel Execution**: NO（2个任务顺序执行，都很小）
> **Critical Path**: Task 1 → Task 2 → Task 3（验证）

---

## Context

### 已知 Bug

**Bug 1 - SSEParser 不识别 Anthropic 流式格式**

Anthropic Messages API 流式响应格式为：
```json
{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}
```
当前 `extractContent` 只处理了：
- `choices[0].delta.content`（OpenAI/Qwen）
- `choices[0].message.content`（非流式回退）
- `delta.text`（旧格式）

未处理 `type == "content_block_delta"` 分支，导致 Anthropic 流式对话所有 token 被静默丢弃，用户看不到任何输出。

**Bug 2 - AnthropicProvider.embedding 调用不存在端点**

Anthropic 官方**不提供** embedding API（截至 2026-05）。当前实现向 `/v1/embeddings` 发请求，必然 404。应改为立即抛出明确错误，调用方（EmbeddingEngine）可据此降级或报错。

### 相关文件

- `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/SSEParser.swift`（112行）
- `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift`（142行）
- `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/LLMProvider.swift`（LLMProviderError 定义）

---

## Work Objectives

### Core Objective
修复两个 bug，使 Anthropic 流式对话可正常输出 token，并让 embedding 不支持的事实在编译期/调用期明确暴露。

### Concrete Deliverables
- `SSEParser.swift` 的 `extractContent` 正确解析 Anthropic `content_block_delta` 事件
- `AnthropicProvider.swift` 的 `embedding` 方法立即 `throw LLMProviderError.notSupported("Anthropic does not provide an embedding API")`

### Must Have
- `extractContent` 新分支放在所有其他分支**之前**（优先匹配，避免 Anthropic 响应误入其他分支）
- 删除原来最后那个 `json["content"]` 的无效分支（它本来就匹配不到任何真实格式）
- `LLMProviderError` 中若无 `notSupported` case，则新增；若已有则直接使用

### Must NOT Have
- 不修改除上述两个文件之外的任何文件（除非 `LLMProviderError` 需要新增 case）
- 不引入新的依赖
- 不改变 `SSEParser` 的 public API 签名
- 不改变 `AnthropicProvider.chatCompletion` 的任何逻辑

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES（Swift Testing，`bun test` / `swift test`）
- **Automated tests**: Tests-after（在验证 task 中运行现有测试套件确认无回归）
- **Framework**: Swift Testing

### QA Policy
每个 task 含 agent 执行的 QA 场景，证据保存至 `.sisyphus/evidence/`。

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1（顺序执行，两个改动都很小）:
├── Task 1: 修复 SSEParser.extractContent [quick]
└── Task 2: 修复 AnthropicProvider.embedding [quick]

Wave FINAL:
└── Task 3: swift build + swift test 验证 [quick]
```

---

## TODOs

- [x] 1. 修复 SSEParser：新增 Anthropic content_block_delta 分支

  **What to do**:

  编辑 `SSEParser.swift` 的 `extractContent` 方法：

  1. 在方法最开头（其他所有分支之前）新增以下分支：
     ```swift
     // Anthropic 流式格式：{"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
     if let type_ = json["type"] as? String,
        type_ == "content_block_delta",
        let delta = json["delta"] as? [String: Any],
        let text = delta["text"] as? String {
         return text
     }
     ```

  2. 删除当前最后一个无效分支（第 91-94 行）：
     ```swift
     if let content = json["content"] as? [String: Any],
        let text = content.first?.value as? String {
         return text
     }
     ```
     该分支逻辑错误且从未匹配到任何真实 API 响应，删除。

  3. 保持其余分支顺序不变（OpenAI choices.delta.content → 非流式 choices.message.content → 旧格式 delta.text）

  **Must NOT do**:
  - 不修改 `parseStream`、`processBuffer`、`reset` 等其他方法
  - 不改动 `SSEParserError` 枚举

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO（先完成此 task，再做 Task 2）
  - **Parallel Group**: Wave 1，Task 1 先执行
  - **Blocks**: Task 3
  - **Blocked By**: None

  **References**:

  **文件参考**:
  - `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/SSEParser.swift:65-101` — 当前 `extractContent` 实现，直接在此修改

  **Anthropic 流式 SSE 格式参考**（官方文档）:
  Anthropic Messages API 流式模式下，每个 token 对应一个 SSE event，`data:` 字段内容格式为：
  ```json
  {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"token"}}
  ```
  流结束时会有 `{"type":"message_stop"}` 事件，以及 `data: [DONE]`（某些版本）。
  只需匹配 `type == "content_block_delta"` 且 `delta.text` 存在即可提取 token。

  **Acceptance Criteria**:

  - [ ] `SSEParser.swift` 的 `extractContent` 在最开头新增了 `content_block_delta` 分支
  - [ ] 无效的 `json["content"]` 分支已删除
  - [ ] 文件可编译（`swift build` 无错误）

  **QA Scenarios**:

  ```
  Scenario: extractContent 正确解析 Anthropic content_block_delta
    Tool: Bash（swift REPL 或单元测试）
    Steps:
      1. 打开终端，进入 Package 目录：
         cd /Users/hanxiaoming/Desktop/github/my-known/Packages/KnowledgeVaultCore
      2. 运行 swift build 确认编译通过：
         swift build 2>&1
      3. 预期输出包含 "Build complete!" 且无 error
    Expected Result: Build complete! 无错误行
    Evidence: .sisyphus/evidence/task-1-build.txt

  Scenario: 现有测试套件无回归
    Tool: Bash
    Steps:
      1. cd /Users/hanxiaoming/Desktop/github/my-known/Packages/KnowledgeVaultCore
      2. swift test 2>&1
      3. 预期所有测试通过
    Expected Result: Test Suite ... passed，0 failures
    Evidence: .sisyphus/evidence/task-1-test.txt
  ```

  **Commit**: NO（与 Task 2 一起提交）

---

- [x] 2. 修复 AnthropicProvider.embedding：改为抛出 notSupported 错误

  **What to do**:

  1. 先检查 `LLMProvider.swift` 中 `LLMProviderError` 枚举是否已有 `notSupported` case：
     - 若**有**：直接进入步骤 2
     - 若**无**：在 `LLMProviderError` 枚举中新增：
       ```swift
       case notSupported(String)
       ```

  2. 将 `AnthropicProvider.swift` 的 `embedding(text:model:)` 方法体**完全替换**为：
     ```swift
     public func embedding(text: String, model: String) async throws -> [Float] {
         // Anthropic 官方不提供 Embedding API
         throw LLMProviderError.notSupported("Anthropic does not provide an embedding API. Use OpenAI or other providers for embeddings.")
     }
     ```

  3. 删除原方法体中所有的 URLRequest 构造、网络请求、JSON 解析代码。

  **Must NOT do**:
  - 不修改 `chatCompletion` 方法
  - 不修改 `init`、属性声明
  - 不在 `LLMProvider.swift` 中做除新增 `notSupported` case 之外的任何修改

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: 可在 Task 1 完成后立即执行，或与 Task 1 同 wave 并行（两者无依赖）
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 3
  - **Blocked By**: None

  **References**:

  **文件参考**:
  - `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift:101-141` — 当前 `embedding` 方法，完整替换方法体
  - `Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/LLMProvider.swift` — `LLMProviderError` 枚举定义，确认/新增 `notSupported` case

  **Acceptance Criteria**:

  - [ ] `AnthropicProvider.embedding` 方法体只剩一行 `throw LLMProviderError.notSupported(...)`
  - [ ] 原来的网络请求代码已全部删除
  - [ ] `LLMProviderError` 中存在 `notSupported(String)` case（新增或已有）
  - [ ] `swift build` 无错误

  **QA Scenarios**:

  ```
  Scenario: embedding 调用立即抛出 notSupported 错误（不发网络请求）
    Tool: Bash
    Steps:
      1. swift build 2>&1 | tee .sisyphus/evidence/task-2-build.txt
      2. grep -c "notSupported" Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift
         预期输出: 1（至少一次出现）
      3. grep -c "urlSession.data" Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift
         预期输出: 0（旧网络代码已删除）
    Expected Result: build 通过，notSupported 出现，urlSession.data 不出现
    Evidence: .sisyphus/evidence/task-2-build.txt
  ```

  **Commit**: YES（Task 1 + Task 2 合并一次提交）
  - Message: `fix(llm): fix SSEParser Anthropic SSE format + remove invalid Anthropic embedding`
  - Files: `SSEParser.swift`, `AnthropicProvider.swift`（可能还有 `LLMProvider.swift`）
  - Pre-commit: `swift build`

---

- [x] 3. 最终验证：swift build + swift test

  **What to do**:

  1. 在 Package 根目录运行 `swift build`，确认 Build complete!，无 error/warning
  2. 运行 `swift test`，确认所有测试通过，无 failure
  3. 将输出保存为证据文件

  **Must NOT do**:
  - 不修改任何源码（纯验证任务）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO（必须在 Task 1 + Task 2 都完成后执行）
  - **Parallel Group**: Wave FINAL
  - **Blocks**: 无
  - **Blocked By**: Task 1, Task 2

  **References**:
  - Package 目录：`/Users/hanxiaoming/Desktop/github/my-known/Packages/KnowledgeVaultCore`

  **Acceptance Criteria**:

  - [ ] `swift build` 输出 `Build complete!`，无 error
  - [ ] `swift test` 输出所有 test passed，failures = 0

  **QA Scenarios**:

  ```
  Scenario: 完整构建和测试
    Tool: Bash
    Steps:
      1. cd /Users/hanxiaoming/Desktop/github/my-known/Packages/KnowledgeVaultCore
      2. swift build 2>&1 | tee .sisyphus/evidence/task-3-build.txt
      3. swift test 2>&1 | tee .sisyphus/evidence/task-3-test.txt
      4. grep "Build complete!" .sisyphus/evidence/task-3-build.txt
      5. grep -E "passed|Test Suite" .sisyphus/evidence/task-3-test.txt
    Expected Result: Build complete! + 全部测试通过
    Evidence: .sisyphus/evidence/task-3-build.txt, .sisyphus/evidence/task-3-test.txt
  ```

  **Commit**: NO

---

## Success Criteria

```bash
# 在 Package 目录执行
swift build     # 预期: Build complete!
swift test      # 预期: 0 failures
grep "content_block_delta" Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/SSEParser.swift  # 预期: 有输出
grep "notSupported" Packages/KnowledgeVaultCore/Sources/KnowledgeVaultCore/LLM/AnthropicProvider.swift # 预期: 有输出
```

### Final Checklist
- [ ] SSEParser 正确解析 Anthropic content_block_delta 格式
- [ ] AnthropicProvider.embedding 抛出 notSupported 而非发起无效网络请求
- [ ] swift build 无错误
- [ ] 所有现有测试通过（无回归）
