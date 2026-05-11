import Foundation

public class VaultDirectoryPresenter: NSObject, NSFilePresenter {
    public var presentedItemURL: URL?
    public let presentedItemOperationQueue: OperationQueue
    
    private let notificationName = Notification.Name("VaultDirectoryDidChange")
    
    public init(vaultURL: URL) {
        self.presentedItemURL = vaultURL
        self.presentedItemOperationQueue = OperationQueue.main
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    public func presentedItemDidChange() {
        NotificationCenter.default.post(name: notificationName, object: self)
    }
    
    public func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}
