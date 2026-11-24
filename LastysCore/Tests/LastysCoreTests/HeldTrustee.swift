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
    func sendRelationshipRequest(scanID: String) async throws -> RelationshipRequest { try await wrapped.sendRelationshipRequest(scanID: scanID) }
    func relationshipRequest(id: String) async throws -> RelationshipRequest { try await wrapped.relationshipRequest(id: id) }
    func respondToRelationshipRequest(id: String, accept: Bool) async throws { try await wrapped.respondToRelationshipRequest(id: id, accept: accept) }

    func scan(_ payload: String) async throws -> ScanResult {
        await withCheckedContinuation { continuation in
            lock.withLock { held.append(continuation) }
        }
        return try await wrapped.scan(payload)
    }
}
