import Crypto
import Foundation

/// What a Lastys QR encodes: a token signed by the showing phone's key, naming the Lastys ID and its
/// QR number. The QR stays the same, and works offline, until its owner presses Revoke: that makes
/// Trustee accept only the next QR number, so every older copy, such as a screenshot, stops working.
/// Making one needs no network; revoking does.
///
/// Text form, shared with the real Trustee: `LT2.<Personal ID>.<QR number>.<signature>`, where
/// - the QR number starts at 0 and goes up by one with every Revoke, in plain decimal with no leading zeros or sign;
/// - the signature is ECDSA P-256 with SHA-256 over the UTF-8 bytes of `LT2.<Personal ID>.<QR number>`,
///   in raw r‖s form (64 bytes, IEEE P1363), base64url-encoded without padding.
/// Any other spelling is not a Lastys QR, so the fake and the real Trustee accept exactly the same tokens.
public struct LastysQRToken: Equatable, Sendable {
    static let version = "LT2"

    public let personalID: String
    public let number: Int
    public let signature: Data

    /// The part the signature covers.
    public var signedText: String { "\(Self.version).\(personalID).\(number)" }

    public var text: String { "\(signedText).\(signature.base64URLEncodedString())" }

    /// Signs a token for this Lastys ID and QR number.
    public init(personalID: String, number: Int = 0, signedBy key: PhoneKey) throws {
        let unsigned = LastysQRToken(personalID: personalID, number: number, signature: Data())
        let signature = try key.signature(for: Data(unsigned.signedText.utf8))
        self.init(personalID: personalID, number: number, signature: signature.rawRepresentation)
    }

    private init(personalID: String, number: Int, signature: Data) {
        self.personalID = personalID
        self.number = number
        self.signature = signature
    }

    /// Reads a scanned QR. Returns nil unless it is a Lastys QR in exactly its text form;
    /// a readable token may still be forged, which `isSigned(by:)` checks.
    public init?(parsing text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == Self.version,
              let number = Int(parts[2]), number >= 0,
              let signature = Data(base64URLEncoded: parts[3])
        else { return nil }
        self.init(personalID: parts[1], number: number, signature: signature)
        guard self.text == text else { return nil }
    }

    /// True when the phone holding this public key signed exactly this Lastys ID and QR number.
    public func isSigned(by publicKey: P256.Signing.PublicKey) -> Bool {
        guard let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else { return false }
        return publicKey.isValidSignature(signature, for: Data(signedText.utf8))
    }
}

/// My Lastys QR as shown on screen: what to encode.
public struct MyLastysQR: Equatable, Sendable {
    public let payload: String
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded text: String) {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
