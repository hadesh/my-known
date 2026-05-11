import Foundation

public enum SyncStatus {
    case idle
    case syncing
    case error(Error)
    case disabled
}

public enum ConflictResolution {
    case useLocal
    case useRemote
    case merge(Entry)
}

public struct File {
    public let entry: Entry
    public let modifiedAt: Date
}

public actor SyncManager {
    private var presenter: VaultDirectoryPresenter?
    private var currentStatus: SyncStatus = .disabled
    private let vaultURL: URL
    
    public init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }
    
    public func enableICloud() async throws {
        presenter = VaultDirectoryPresenter(vaultURL: vaultURL)
        currentStatus = .idle
    }
    
    public func disableICloud() async throws {
        presenter = nil
        currentStatus = .disabled
    }
    
    public func syncStatus() async -> SyncStatus {
        return currentStatus
    }
    
    public func handleConflict(local: File, remote: File) async -> ConflictResolution {
        return ConflictResolver.resolve(local: local, remote: remote)
    }
    
    public func syncNow() async throws {
        guard case .idle = currentStatus else { return }
        currentStatus = .syncing
        defer { currentStatus = .idle }
    }
}
