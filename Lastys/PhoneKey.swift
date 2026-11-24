import CryptoKit
import Foundation
import Security

/// This phone's key, the only credential Lastys has (ADR 0003).
///
/// The private key is created in the Secure Enclave and can never leave it. The Keychain keeps only
/// the Secure Enclave's opaque handle to it, on this device only, so a backup can't carry it anywhere.
/// Debug builds on a simulator, which has no Secure Enclave, fall back to a software key.
enum PhoneKey {
    enum Problem: Error {
        case noSecureEnclave
        case keychain(OSStatus)
    }

    /// Loads this phone's key, creating it on first launch, and returns how Trustee identifies it:
    /// the public key, base64-encoded.
    static func loadOrCreate() throws -> String {
        let stored = try readFromKeychain()
        let keyData = try stored ?? makeKey()
        if stored == nil { try saveToKeychain(keyData) }
        return try publicKey(from: keyData).compressedRepresentation.base64EncodedString()
    }

    private static func makeKey() throws -> Data {
        if SecureEnclave.isAvailable {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, .privateKeyUsage, &error
            ) else { throw error!.takeRetainedValue() as Error }
            return try SecureEnclave.P256.Signing.PrivateKey(accessControl: access).dataRepresentation
        }
        #if DEBUG
        return P256.Signing.PrivateKey().rawRepresentation
        #else
        throw Problem.noSecureEnclave
        #endif
    }

    private static func publicKey(from keyData: Data) throws -> P256.Signing.PublicKey {
        if SecureEnclave.isAvailable {
            return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData).publicKey
        }
        #if DEBUG
        return try P256.Signing.PrivateKey(rawRepresentation: keyData).publicKey
        #else
        throw Problem.noSecureEnclave
        #endif
    }

    // MARK: Keychain

    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.lastys.app",
        kSecAttrAccount as String: "phone-key",
    ]

    private static func readFromKeychain() throws -> Data? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Problem.keychain(status) }
        return result as? Data
    }

    private static func saveToKeychain(_ keyData: Data) throws {
        var attributes = item
        attributes[kSecValueData as String] = keyData
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Problem.keychain(status) }
    }
}
