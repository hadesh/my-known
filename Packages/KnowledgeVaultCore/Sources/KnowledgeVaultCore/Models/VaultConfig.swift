import Foundation

public struct VaultConfig {
    public var vaultRootURL: URL
    public var hybridAlpha: Double  // 默认 0.4（FTS 权重），语义权重 = 1 - hybridAlpha
    
    public init(vaultRootURL: URL, hybridAlpha: Double = 0.4) {
        self.vaultRootURL = vaultRootURL
        self.hybridAlpha = hybridAlpha
    }
}