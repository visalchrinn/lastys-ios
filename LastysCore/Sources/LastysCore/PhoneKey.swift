import Crypto
import Foundation

/// This phone's key, the only credential Lastys has (ADR 0003).
/// On an iPhone the private key lives in the Secure Enclave and never leaves it.
public protocol PhoneKey: Sendable {
    var publicKey: P256.Signing.PublicKey { get }
    func signature(for data: Data) throws -> P256.Signing.ECDSASignature
}

extension PhoneKey {
    /// How Trustee tells phones apart: the public key, compressed and base64-encoded.
    public var trusteeID: String {
        publicKey.compressedRepresentation.base64EncodedString()
    }
}

/// A phone key held in memory rather than the Secure Enclave: for tests, and for Debug builds on a
/// simulator, which has no Secure Enclave.
public struct SoftwarePhoneKey: PhoneKey, @unchecked Sendable {
    private let privateKey: P256.Signing.PrivateKey

    public init() {
        privateKey = P256.Signing.PrivateKey()
    }

    public init(rawRepresentation: Data) throws {
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    public var rawRepresentation: Data { privateKey.rawRepresentation }

    public var publicKey: P256.Signing.PublicKey { privateKey.publicKey }

    public func signature(for data: Data) throws -> P256.Signing.ECDSASignature {
        try privateKey.signature(for: data)
    }
}
