import Foundation
import CryptoKit
import Security

@Observable
final class SecurityService {
    private let keychainService = "com.budgify.security"
    private let keychainAccount = "budgify.symmetric.key.v1"

    func hash(_ text: String) -> String {
        hash(data: Data(text.utf8))
    }

    func hash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func encrypt(_ plaintext: String) -> String? {
        guard let data = plaintext.data(using: .utf8) else { return nil }
        return encrypt(data: data)?.base64EncodedString()
    }

    func decrypt(_ payloadBase64: String) -> String? {
        guard let data = Data(base64Encoded: payloadBase64), let decrypted = decrypt(data: data) else { return nil }
        return String(data: decrypted, encoding: .utf8)
    }

    func encrypt(data: Data) -> Data? {
        do {
            let box = try AES.GCM.seal(data, using: try key())
            return box.combined
        } catch {
            return nil
        }
    }

    func decrypt(data: Data) -> Data? {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: try key())
        } catch {
            return nil
        }
    }

    func rotateKey() {
        let newKey = SymmetricKey(size: .bits256)
        let data = newKey.withUnsafeBytes { Data($0) }
        saveKeyDataToKeychain(data)
    }

    private func key() throws -> SymmetricKey {
        if let existing = readKeyDataFromKeychain() {
            return SymmetricKey(data: existing)
        }

        let newKey = SymmetricKey(size: .bits256)
        let data = newKey.withUnsafeBytes { Data($0) }
        saveKeyDataToKeychain(data)
        return newKey
    }

    private func readKeyDataFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func saveKeyDataToKeychain(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
