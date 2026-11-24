import CryptoKit
import Foundation
import LastysCore
import Security

/// Loads this phone's key, creating it on first launch (ADR 0003).
///
/// The private key is created in the Secure Enclave and can never leave it. The Keychain keeps only
/// the Secure Enclave's opaque handle to it, on this device only, so a backup can't carry it anywhere.
/// Debug builds on a simulator, which has no Secure Enclave, fall back to a software key.
enum PhoneKeyStore {
    enum Problem: Error {
        case noSecureEnclave
        case keychain(OSStatus)
    }

    static func loadOrCreate() throws -> PhoneKey {
        let stored = try readFromKeychain()
        let keyData = try stored ?? makeKey()
        if stored == nil { try saveToKeychain(keyData) }
        return try key(from: keyData)
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
        return SoftwarePhoneKey().rawRepresentation
        #else
        throw Problem.noSecureEnclave
        #endif
    }

    private static func key(from keyData: Data) throws -> PhoneKey {
        if SecureEnclave.isAvailable {
            return SecureEnclavePhoneKey(privateKey: try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData))
        }
        #if DEBUG
        return try SoftwarePhoneKey(rawRepresentation: keyData)
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

/// The phone's key inside the Secure Enclave. Signing happens in the enclave.
private struct SecureEnclavePhoneKey: PhoneKey, @unchecked Sendable {
    let privateKey: SecureEnclave.P256.Signing.PrivateKey

    var publicKey: P256.Signing.PublicKey { privateKey.publicKey }

    func signature(for data: Data) throws -> P256.Signing.ECDSASignature {
        try privateKey.signature(for: data)
    }
}
