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

    func relationshipStatus() async throws -> RelationshipStatus {
        record("relationshipStatus()")
        return try await wrapped.relationshipStatus()
    }
}
