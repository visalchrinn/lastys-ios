/// The app's single boundary to Trustee.
///
/// One client belongs to one phone. Every call acts as the Lastys ID held on that phone,
/// because the phone's key is the only credential (ADR 0003).
public protocol TrusteeClient: Sendable {
    func createLastysID(nickname: String) async throws -> LastysID
    func relationshipStatus() async throws -> RelationshipStatus
}

public enum TrusteeError: Error, Equatable, Sendable {
    /// The phone has no Lastys ID yet.
    case noLastysID
    /// The phone already holds a Lastys ID (ADR 0001).
    case phoneAlreadyHasLastysID
}
