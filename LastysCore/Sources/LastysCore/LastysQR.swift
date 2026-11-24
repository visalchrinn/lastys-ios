import Crypto
import Foundation

/// What a Lastys QR encodes: a token signed by the showing phone's key, naming the Lastys ID and
/// the minute it was made. Trustee rejects it once that minute is too old, so a screenshot can't be
/// reused. Making one needs no network.
///
/// Text form, shared with the real Trustee: `LT1.<Personal ID>.<minute>.<signature>`, where
/// - the minute counts whole minutes since 1970 (UTC), in plain decimal with no leading zeros or sign;
/// - the signature is ECDSA P-256 with SHA-256 over the UTF-8 bytes of `LT1.<Personal ID>.<minute>`,
///   in raw r‖s form (64 bytes, IEEE P1363), base64url-encoded without padding.
/// Any other spelling is not a Lastys QR, so the fake and the real Trustee accept exactly the same tokens.
public struct LastysQRToken: Equatable, Sendable {
    static let version = "LT1"
    /// A Lastys QR is replaced by a new one every minute.
    public static let secondsPerCode = 60
    /// How long after a code began a Verified Single card promises it still works. Trustee decides how long it
    /// really accepts a code, and a card must never promise more than that, so this stays on the safe side.
    public static let secondsCardPromisesValid = 2 * secondsPerCode

    public let personalID: String
    public let minute: Int64
    public let signature: Data

    /// The part the signature covers.
    public var signedText: String { "\(Self.version).\(personalID).\(minute)" }

    public var text: String { "\(signedText).\(signature.base64URLEncodedString())" }

    /// Signs a token for this Lastys ID and the minute containing `date`.
    public init(personalID: String, at date: Date, signedBy key: PhoneKey) throws {
        let unsigned = LastysQRToken(personalID: personalID, minute: Self.minute(containing: date), signature: Data())
        let signature = try key.signature(for: Data(unsigned.signedText.utf8))
        self.init(personalID: personalID, minute: unsigned.minute, signature: signature.rawRepresentation)
    }

    private init(personalID: String, minute: Int64, signature: Data) {
        self.personalID = personalID
        self.minute = minute
        self.signature = signature
    }

    /// Reads a scanned QR. Returns nil unless it is a Lastys QR in exactly its text form;
    /// a readable token may still be forged, which `isSigned(by:)` checks.
    public init?(parsing text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == Self.version,
              let minute = Int64(parts[2]), minute >= 0,
              let signature = Data(base64URLEncoded: parts[3])
        else { return nil }
        self.init(personalID: parts[1], minute: minute, signature: signature)
        guard self.text == text else { return nil }
    }

    /// True when the phone holding this public key signed exactly this Lastys ID and minute.
    public func isSigned(by publicKey: P256.Signing.PublicKey) -> Bool {
        guard let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else { return false }
        return publicKey.isValidSignature(signature, for: Data(signedText.utf8))
    }

    public static func minute(containing date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 / Double(secondsPerCode)).rounded(.down))
    }

    /// When the minute containing `date` began: the moment the current code replaced the last one.
    public static func startOfMinute(containing date: Date) -> Date {
        Date(timeIntervalSince1970: Double(minute(containing: date) * Int64(secondsPerCode)))
    }

    /// Whole seconds from `date` until the next code, from 60 down to 1.
    public static func secondsUntilNextCode(after date: Date) -> Int {
        secondsPerCode - Int(date.timeIntervalSince(startOfMinute(containing: date)))
    }
}

/// My Lastys QR as shown on screen: what to encode, and how long until the next code replaces it.
public struct MyLastysQR: Equatable, Sendable {
    public let payload: String
    /// Whole seconds until the next code, from 60 down to 1.
    public let secondsUntilNextCode: Int
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
