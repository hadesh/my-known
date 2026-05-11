
## Task 8: SyncManager actor + ConflictResolver + VaultDirectoryPresenter

### 实现日期
2025-05-09

### 关键发现
- NSFilePresenter 协议要求必须实现 `presentedItemOperationQueue` 属性，最初遗漏导致编译错误
- ConflictResolver 采用 last-write-wins 策略：modifiedAt 较新者胜，相同时 remote 优先
- actor SyncManager 可以持有 NSObject 子类 (VaultDirectoryPresenter) 作为实例变量
- NSFileCoordinator.addFilePresenter/removeFilePresenter 在 init/deinit 中调用需要注意 retain cycle

### 文件结构
- SyncManager.swift: actor SyncManager + SyncStatus enum + ConflictResolution enum + File struct
- ConflictResolver.swift: struct ConflictResolver 含 static func resolve
- VaultDirectoryPresenter.swift: class VaultDirectoryPresenter: NSObject, NSFilePresenter

### 验证结果
- swift build: Build complete!
- grep handleConflict: ✓ 存在
- grep static func resolve: ✓ 存在
- grep let modifiedAt: ✓ 存在
