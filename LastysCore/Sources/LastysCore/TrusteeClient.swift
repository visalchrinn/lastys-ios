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
    /// Resolves a scanned Lastys QR into what that Lastys ID shows right now.
    func scan(_ payload: String) async throws -> ScanResult
    /// Offers a Relationship to the person this phone just Scanned. There is no way to name anyone else:
    /// no lookup by Personal ID, so nobody can be targeted remotely.
    func sendRelationshipRequest(scanID: String) async throws -> RelationshipRequest
    /// Where a Relationship request this phone sent stands now.
    func relationshipRequest(id: String) async throws -> RelationshipRequest
    /// The receiver accepts or declines a Relationship request. Accepting starts the Relationship.
    func respondToRelationshipRequest(id: String, accept: Bool) async throws
    /// Asks the Partner to agree to end the Relationship. Both stay Taken while they have 7 days to answer.
    func sendEndRequest() async throws
    /// The requester takes their End request back; the Relationship carries on.
    func withdrawEndRequest() async throws
    /// The other Partner agrees (the Relationship ends) or declines.
    func respondToEndRequest(agree: Bool) async throws
    /// After a decline, or 7 days with no answer, the requester asks the Lastys team to decide.
    func escalateToTeamReview() async throws
    /// Either Partner, at any stage: the Lastys team reviews the Relationship within 24 hours.
    func reportSafetyConcern() async throws
    /// Replaces the Moments this Partner shares into the Relationship. Only Shared Moments are ever sent.
    func setMySharedMoments(_ moments: [SharedMoment]) async throws
    /// What the Partner shares into the Relationship.
    func partnerSharedMoments() async throws -> [SharedMoment]
    /// After a Relationship ends: this person's own copy of what the former Partner shared, until they decide.
    func formerSharedMoments() async throws -> [SharedMoment]
    /// This person has kept (on the phone) or deleted their copy; the former Partner's copy is untouched.
    func discardFormerSharedMoments() async throws
    /// What a Scan of this Lastys ID shows: Status only, or Status + history.
    func setShareLevel(_ level: ShareLevel) async throws
    func myLastysIDDetails() async throws -> MyLastysIDDetails
    /// When this Lastys ID was Scanned, newest first. Never who scanned: only the Lastys team may know that.
    func whoScannedMe() async throws -> [Date]
    /// Replaces the Recovery code. Trustee keeps only its hash, and the old code stops working.
    func newRecoveryCode() async throws -> String
    /// From a new phone: starts a Recovery with a Recovery code. It completes after a 7-day wait (#15).
    func startRecovery(recoveryCode: String) async throws -> RecoveryStarted
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
    /// The scanned code isn't a Lastys QR at all.
    case notALastysQR
    /// The Lastys QR was made too long ago; it may be a screenshot.
    case expiredQR
    /// The Lastys QR wasn't signed by that Lastys ID's own phone.
    case forgedQR
    /// A Relationship request must follow a Scan this phone made.
    case scanRequired
    /// The Scan was too long ago; Scan them again.
    case scanTooOld
    /// This Lastys ID already has an active Relationship.
    case youAreTaken
    /// This Lastys ID is in a Cooling-off period.
    case youAreCoolingOff
    /// The other Lastys ID already has an active Relationship.
    case theyAreTaken
    /// The other Lastys ID is in a Cooling-off period.
    case theyAreCoolingOff
    /// A Relationship needs two different Lastys IDs.
    case thatIsYou
    /// No such Relationship request for this phone.
    case requestNotFound
    /// The Relationship request was already answered or has expired.
    case requestNotPending
    /// This Lastys ID has no active Relationship.
    case noRelationship
    /// The Relationship's current stage doesn't allow this, or this Partner can't do it.
    case notAllowedNow
    /// A Team review needs a declined End request, or 7 days without an answer.
    case cannotEscalateYet
    /// No Lastys ID has this Recovery code (or it was replaced by a newer one).
    case wrongRecoveryCode
}
