# Issues

## 已知问题
- SearchResult: Identifiable 但字段名为 fileID，需加计算属性 var id: String { fileID }
- AnthropicProvider: system 字段必须独立，不能放入 messages 数组
- Entry 表 id 列必须为 TEXT（不能 INTEGER）
