/// Trustee running on the phone for Phase A. It holds every Lastys ID in memory and enforces
/// the same domain rules the real Trustee will. Hand each phone its own client.
public actor FakeTrustee {
    private var lastysIDByPhone: [String: LastysID] = [:]

    public init() {}

    public nonisolated func client(forPhone phone: String) -> TrusteeClient {
        Client(trustee: self, phone: phone)
    }

    func createLastysID(phone: String, nickname: String) throws -> LastysID {
        // ADR 0001: a device that already holds a Lastys ID cannot create another.
        guard lastysIDByPhone[phone] == nil else { throw TrusteeError.phoneAlreadyHasLastysID }
        let taken = Set(lastysIDByPhone.values)
        var id = LastysID(personalID: Self.randomPersonalID())
        while taken.contains(id) { id = LastysID(personalID: Self.randomPersonalID()) }
        lastysIDByPhone[phone] = id
        return id
    }

    func relationshipStatus(phone: String) throws -> RelationshipStatus {
        guard lastysIDByPhone[phone] != nil else { throw TrusteeError.noLastysID }
        return .none
    }

    private static func randomPersonalID() -> String {
        let alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        func block() -> String { String((0..<4).map { _ in alphabet.randomElement()! }) }
        return "LT-\(block())-\(block())"
    }

    private struct Client: TrusteeClient {
        let trustee: FakeTrustee
        let phone: String

        func createLastysID(nickname: String) async throws -> LastysID {
            try await trustee.createLastysID(phone: phone, nickname: nickname)
        }

        func relationshipStatus() async throws -> RelationshipStatus {
            try await trustee.relationshipStatus(phone: phone)
        }
    }
}
