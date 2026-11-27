import Foundation
import LastysCore

/// Wraps a TrusteeClient and holds every Scan until `release()`, so a test can act while one is in flight.
final class HeldTrustee: TrusteeClient, @unchecked Sendable {
    private let wrapped: TrusteeClient
    private let lock = NSLock()
    private var held: [CheckedContinuation<Void, Never>] = []

    init(_ wrapped: TrusteeClient) {
        self.wrapped = wrapped
    }

    var heldScans: Int { lock.withLock { held.count } }

    func release() {
        let waiting = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            defer { held = [] }
            return held
        }
        waiting.forEach { $0.resume() }
    }

    func createLastysID() async throws -> NewLastysID { try await wrapped.createLastysID() }
    func updateProfile(nickname: String, photo: Data?) async throws { try await wrapped.updateProfile(nickname: nickname, photo: photo) }
    func relationshipStatus() async throws -> RelationshipStatus { try await wrapped.relationshipStatus() }
    func sendEndRequest() async throws { try await wrapped.sendEndRequest() }
    func withdrawEndRequest() async throws { try await wrapped.withdrawEndRequest() }
    func respondToEndRequest(agree: Bool) async throws { try await wrapped.respondToEndRequest(agree: agree) }
    func escalateToTeamReview() async throws { try await wrapped.escalateToTeamReview() }
    func reportSafetyConcern() async throws { try await wrapped.reportSafetyConcern() }
    func setMySharedMoments(_ moments: [SharedMoment]) async throws { try await wrapped.setMySharedMoments(moments) }
    func partnerSharedMoments() async throws -> [SharedMoment] { try await wrapped.partnerSharedMoments() }
    func formerSharedMoments() async throws -> [SharedMoment] { try await wrapped.formerSharedMoments() }
    func discardFormerSharedMoments() async throws { try await wrapped.discardFormerSharedMoments() }
    func setShareLevel(_ level: ShareLevel) async throws { try await wrapped.setShareLevel(level) }
    func myLastysIDDetails() async throws -> MyLastysIDDetails { try await wrapped.myLastysIDDetails() }
    func whoScannedMe() async throws -> [Date] { try await wrapped.whoScannedMe() }
    func newRecoveryCode() async throws -> String { try await wrapped.newRecoveryCode() }
    func startRecovery(recoveryCode: String) async throws -> RecoveryStarted { try await wrapped.startRecovery(recoveryCode: recoveryCode) }
    func deleteMyData() async throws { try await wrapped.deleteMyData() }
    func startPhoneTransfer(sealedBundle: Data) async throws -> PhoneTransferOffer { try await wrapped.startPhoneTransfer(sealedBundle: sealedBundle) }
    func completePhoneTransfer(code: String) async throws -> TransferredLastysID { try await wrapped.completePhoneTransfer(code: code) }
    func recoveryStatus() async throws -> RecoveryStatus { try await wrapped.recoveryStatus() }
    func completeRecovery() async throws -> NewLastysID { try await wrapped.completeRecovery() }
    func cancelRecovery() async throws { try await wrapped.cancelRecovery() }
    func notices() async throws -> [Notice] { try await wrapped.notices() }
    func sendRelationshipRequest(scanID: String) async throws -> RelationshipRequest { try await wrapped.sendRelationshipRequest(scanID: scanID) }
    func relationshipRequest(id: String) async throws -> RelationshipRequest { try await wrapped.relationshipRequest(id: id) }
    func respondToRelationshipRequest(id: String, accept: Bool) async throws { try await wrapped.respondToRelationshipRequest(id: id, accept: accept) }
    func createInviteLink() async throws -> InviteLink { try await wrapped.createInviteLink() }
    func myInviteLink() async throws -> InviteLink? { try await wrapped.myInviteLink() }
    func cancelInviteLink() async throws { try await wrapped.cancelInviteLink() }

    func revokeLastysQR() async throws -> Int { try await wrapped.revokeLastysQR() }

    func scan(_ payload: String) async throws -> ScanResult {
        await withCheckedContinuation { continuation in
            lock.withLock { held.append(continuation) }
        }
        return try await wrapped.scan(payload)
    }
}
