import Foundation

public struct ConflictResolver {
    public static func resolve(local: File, remote: File) -> ConflictResolution {
        if local.modifiedAt > remote.modifiedAt {
            return .useLocal
        } else {
            return .useRemote
        }
    }
}
