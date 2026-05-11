# Decisions

## 架构决策
- 5个 actor：VaultFileManagerImpl/LLMAgent/EmbeddingEngine/SyncManager/SSEParser
- MarkdownRenderer 基于 AttributedString，不引入三方库
- Phase 1 不实现真实 Embedding（骨架 throw EmbeddingError.notImplementedInPhase1）
- Phase 1 语义搜索 throw .notImplemented
- ConflictResolver 策略：modifiedAt 较新者胜，相同时 remote 优先
- token 估算：text.count / 4
- 搜索 debounce：Task.sleep 500ms
- 流式输出缓冲：ChatViewModel.currentStreamingContent
