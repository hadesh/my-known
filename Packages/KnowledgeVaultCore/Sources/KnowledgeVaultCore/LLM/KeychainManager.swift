import Foundation
import Security

public enum KeychainManager {
    private static let servicePrefix = "com.knowledgevault.apikey"
    
    public static func apiKey(for provider: String) throws -> String {
        let key = "\(servicePrefix).\(provider)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: servicePrefix,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return apiKey
    }
    
    public static func saveAPIKey(for provider: String, key: String) throws {
        let keyIdentifier = "\(servicePrefix).\(provider)"
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecAttrService as String: servicePrefix
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keyIdentifier,
                kSecAttrService as String: servicePrefix,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public static func deleteAPIKey(for provider: String) throws {
        let key = "\(servicePrefix).\(provider)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: servicePrefix
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public static func hasAPIKey(for provider: String) -> Bool {
        do {
            _ = try apiKey(for: provider)
            return true
        } catch {
            return false
        }
    }
}

public enum KeychainError: Error {
    case itemNotFound
    case invalidData
    case unhandledError(status: OSStatus)
    
    public var localizedDescription: String {
        switch self {
        case .itemNotFound:
            return "Keychain item not found"
        case .invalidData:
            return "Invalid data retrieved from keychain"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}
