import Foundation
import LastysCore

/// Wraps a TrusteeClient and records every request, arguments included, as it crosses the boundary.
final class RecordingTrustee: TrusteeClient, @unchecked Sendable {
    private let wrapped: TrusteeClient
    private let lock = NSLock()
    private var recorded: [String] = []

    init(_ wrapped: TrusteeClient) {
        self.wrapped = wrapped
    }

    var requests: [String] { lock.withLock { recorded } }

    private func record(_ request: String) {
        lock.withLock { recorded.append(request) }
    }

    func createLastysID() async throws -> NewLastysID {
        record("createLastysID()")
        return try await wrapped.createLastysID()
    }

    func updateProfile(nickname: String, photo: Data?) async throws {
        record("updateProfile(nickname: \(nickname), photo: \(String(describing: photo)))")
        try await wrapped.updateProfile(nickname: nickname, photo: photo)
    }

    func revokeLastysQR() async throws -> Int {
        record("revokeLastysQR()")
        return try await wrapped.revokeLastysQR()
    }

    func scan(_ payload: String) async throws -> ScanResult {
        record("scan(\(payload))")
        return try await wrapped.scan(payload)
    }

    func sendRelationshipRequest(scanID: String) async throws -> RelationshipRequest {
        record("sendRelationshipRequest(scanID: \(scanID))")
        return try await wrapped.sendRelationshipRequest(scanID: scanID)
    }

    func relationshipRequest(id: String) async throws -> RelationshipRequest {
        record("relationshipRequest(id: \(id))")
        return try await wrapped.relationshipRequest(id: id)
    }

    func respondToRelationshipRequest(id: String, accept: Bool) async throws {
        record("respondToRelationshipRequest(id: \(id), accept: \(accept))")
        try await wrapped.respondToRelationshipRequest(id: id, accept: accept)
    }

    func sendEndRequest() async throws {
        record("sendEndRequest()")
        try await wrapped.sendEndRequest()
    }

    func withdrawEndRequest() async throws {
        record("withdrawEndRequest()")
        try await wrapped.withdrawEndRequest()
    }

    func respondToEndRequest(agree: Bool) async throws {
        record(agree ? "respondToEndRequest(agree: true)" : "respondToEndRequest(agree: false)")
        try await wrapped.respondToEndRequest(agree: agree)
    }

    func escalateToTeamReview() async throws {
        record("escalateToTeamReview()")
        try await wrapped.escalateToTeamReview()
    }

    func reportSafetyConcern() async throws {
        record("reportSafetyConcern()")
        try await wrapped.reportSafetyConcern()
    }

    func setMySharedMoments(_ moments: [SharedMoment]) async throws {
        record("setMySharedMoments(" + moments.map(\.title).joined(separator: ", ") + ")")
        try await wrapped.setMySharedMoments(moments)
    }

    func partnerSharedMoments() async throws -> [SharedMoment] {
        record("partnerSharedMoments()")
        return try await wrapped.partnerSharedMoments()
    }

    func formerSharedMoments() async throws -> [SharedMoment] {
        record("formerSharedMoments()")
        return try await wrapped.formerSharedMoments()
    }

    func discardFormerSharedMoments() async throws {
        record("discardFormerSharedMoments()")
        try await wrapped.discardFormerSharedMoments()
    }

    func setShareLevel(_ level: ShareLevel) async throws {
        record("setShareLevel(" + level.rawValue + ")")
        try await wrapped.setShareLevel(level)
    }

    func myLastysIDDetails() async throws -> MyLastysIDDetails {
        record("myLastysIDDetails()")
        return try await wrapped.myLastysIDDetails()
    }

    func whoScannedMe() async throws -> [Date] {
        record("whoScannedMe()")
        return try await wrapped.whoScannedMe()
    }

    func newRecoveryCode() async throws -> String {
        record("newRecoveryCode()")
        return try await wrapped.newRecoveryCode()
    }

    func startRecovery(recoveryCode: String) async throws -> RecoveryStarted {
        record("startRecovery(" + recoveryCode + ")")
        return try await wrapped.startRecovery(recoveryCode: recoveryCode)
    }

    func startPhoneTransfer(sealedBundle: Data) async throws -> PhoneTransferOffer {
        record("startPhoneTransfer(\(sealedBundle.count) sealed bytes)")
        return try await wrapped.startPhoneTransfer(sealedBundle: sealedBundle)
    }

    func completePhoneTransfer(code: String) async throws -> TransferredLastysID {
        record("completePhoneTransfer(\(code))")
        return try await wrapped.completePhoneTransfer(code: code)
    }

    func recoveryStatus() async throws -> RecoveryStatus {
        record("recoveryStatus()")
        return try await wrapped.recoveryStatus()
    }

    func completeRecovery() async throws -> NewLastysID {
        record("completeRecovery()")
        return try await wrapped.completeRecovery()
    }

    func cancelRecovery() async throws {
        record("cancelRecovery()")
        try await wrapped.cancelRecovery()
    }

    func notices() async throws -> [Notice] {
        record("notices()")
        return try await wrapped.notices()
    }

    func deleteMyData() async throws {
        record("deleteMyData()")
        try await wrapped.deleteMyData()
    }

    func relationshipStatus() async throws -> RelationshipStatus {
        record("relationshipStatus()")
        return try await wrapped.relationshipStatus()
    }
}
