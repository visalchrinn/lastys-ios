import Foundation

/// Trustee running on the phone for Phase A. It holds every Lastys ID and enforces
/// the same domain rules the real Trustee will. Hand each phone its own client.
public actor FakeTrustee {
    private struct State: Codable {
        var lastysIDByPhone: [String: LastysID] = [:]
        var profileByLastysID: [String: Profile] = [:]
    }

    /// What a Scan of a Lastys ID shows about them.
    private struct Profile: Codable {
        var nickname: String
        var photo: Data?
    }

    private var state: State
    private let fileURL: URL?

    /// - Parameter fileURL: where to keep Trustee's state between launches; nil keeps it in memory only.
    public init(savingTo fileURL: URL? = nil) {
        self.fileURL = fileURL
        state = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(State.self, from: $0) }
            ?? State()
    }

    public nonisolated func client(forPhone phone: String) -> TrusteeClient {
        Client(trustee: self, phone: phone)
    }

    func createLastysID(phone: String) throws -> NewLastysID {
        // ADR 0001: a device that already holds a Lastys ID cannot create another.
        guard state.lastysIDByPhone[phone] == nil else { throw TrusteeError.phoneAlreadyHasLastysID }
        let inUse = Set(state.lastysIDByPhone.values)
        var id = LastysID(personalID: Self.randomPersonalID())
        while inUse.contains(id) { id = LastysID(personalID: Self.randomPersonalID()) }
        state.lastysIDByPhone[phone] = id
        save()
        return NewLastysID(lastysID: id, recoveryCode: Self.randomRecoveryCode())
    }

    func updateProfile(phone: String, nickname: String, photo: Data?) throws {
        guard let id = state.lastysIDByPhone[phone] else { throw TrusteeError.noLastysID }
        state.profileByLastysID[id.personalID] = Profile(nickname: nickname, photo: photo)
        save()
    }

    func relationshipStatus(phone: String) throws -> RelationshipStatus {
        guard state.lastysIDByPhone[phone] != nil else { throw TrusteeError.noLastysID }
        return .none
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(state) else { return }
        try? data.writeAtomicallyProtected(to: fileURL)
    }

    private static func randomRecoveryCode() -> String {
        (0..<4).map { _ in randomBlock() }.joined(separator: "-")
    }

    private static func randomPersonalID() -> String {
        "LT-\(randomBlock())-\(randomBlock())"
    }

    /// Four characters, leaving out I and O so they can't be misread as 1 and 0.
    private static func randomBlock() -> String {
        let alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        return String((0..<4).map { _ in alphabet.randomElement()! })
    }

    private struct Client: TrusteeClient {
        let trustee: FakeTrustee
        let phone: String

        func createLastysID() async throws -> NewLastysID {
            try await trustee.createLastysID(phone: phone)
        }

        func updateProfile(nickname: String, photo: Data?) async throws {
            try await trustee.updateProfile(phone: phone, nickname: nickname, photo: photo)
        }

        func relationshipStatus() async throws -> RelationshipStatus {
            try await trustee.relationshipStatus(phone: phone)
        }
    }
}
