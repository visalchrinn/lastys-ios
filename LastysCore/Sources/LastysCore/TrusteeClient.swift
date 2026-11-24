import Foundation

/// The app's single boundary to Trustee.
///
/// One client belongs to one phone. Every call acts as the Lastys ID held on that phone,
/// because the phone's key is the only credential (ADR 0003).
/// Nothing here carries a birth date: it never leaves the phone.
public protocol TrusteeClient: Sendable {
    /// Creates a Lastys ID for this phone. Trustee keeps only a hash of the Recovery code.
    func createLastysID() async throws -> NewLastysID
    /// Sets what a Scan of this Lastys ID shows: its nickname and optional photo.
    func updateProfile(nickname: String, photo: Data?) async throws
    func relationshipStatus() async throws -> RelationshipStatus
}

/// What the person is given when their Lastys ID is created.
public struct NewLastysID: Equatable, Sendable {
    public let lastysID: LastysID
    public let recoveryCode: String

    public init(lastysID: LastysID, recoveryCode: String) {
        self.lastysID = lastysID
        self.recoveryCode = recoveryCode
    }
}

public enum TrusteeError: Error, Equatable, Sendable {
    /// The phone has no Lastys ID yet.
    case noLastysID
    /// The phone already holds a Lastys ID (ADR 0001).
    case phoneAlreadyHasLastysID
}
