import Crypto
import Foundation

/// Trustee running on the phone for Phase A. It holds every Lastys ID and enforces
/// the same domain rules the real Trustee will. Hand each phone its own client.
///
/// A phone is known by its key's `trusteeID`, so Trustee can check what that phone signed.
public actor FakeTrustee {
    /// How many minutes back a Lastys QR is still accepted, so a code that just changed still scans.
    public static let qrMinutesAccepted = 2

    struct Person: Codable {
        var lastysID: LastysID
        var createdAt: Date
        var nickname: String = ""
        var photo: Data?
        var shareLevel: ShareLevel = .statusOnly
        /// The Partner's Personal ID while in an active Relationship.
        var partner: String?
        /// When the active Relationship started.
        var relationshipSince: Date?
        /// Until when this Lastys ID can't send or accept a Relationship request.
        var coolingOffUntil: Date?
        var pastRelationships: [PastRelationship] = []
        var phoneTransferCount = 0

        init(lastysID: LastysID, createdAt: Date, nickname: String = "", photo: Data? = nil) {
            self.lastysID = lastysID
            self.createdAt = createdAt
            self.nickname = nickname
            self.photo = photo
        }

        /// Fields added by later builds start empty, so earlier files still load.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lastysID = try c.decode(LastysID.self, forKey: .lastysID)
            createdAt = try c.decode(Date.self, forKey: .createdAt)
            nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
            photo = try c.decodeIfPresent(Data.self, forKey: .photo)
            shareLevel = try c.decodeIfPresent(ShareLevel.self, forKey: .shareLevel) ?? .statusOnly
            partner = try c.decodeIfPresent(String.self, forKey: .partner)
            relationshipSince = try c.decodeIfPresent(Date.self, forKey: .relationshipSince)
            coolingOffUntil = try c.decodeIfPresent(Date.self, forKey: .coolingOffUntil)
            pastRelationships = try c.decodeIfPresent([PastRelationship].self, forKey: .pastRelationships) ?? []
            phoneTransferCount = try c.decodeIfPresent(Int.self, forKey: .phoneTransferCount) ?? 0
        }
    }

    /// One Scan: who scanned whom, and when. Only the Lastys team may see who scanned (Phase B).
    struct ScanRecord: Codable {
        var scanner: String
        var scanned: String
        var at: Date
    }

    struct RequestRecord: Codable {
        var from: String
        var to: String
        var status: String
        var sentAt: Date
    }

    struct State: Codable {
        var lastysIDByPhone: [String: LastysID] = [:]
        var people: [String: Person] = [:]
        var scans: [String: ScanRecord] = [:]
        var requests: [String: RequestRecord] = [:]
        /// How each ending is going, by `FakeTrustee.relationshipKey`. No record means together.
        var endings: [String: EndingRecord] = [:]

        init() {}

        /// Earlier builds didn't record when a Lastys ID was made; `FakeTrustee.init` replaces this.
        static let notYetKnown = Date.distantPast

        /// Missing fields start empty, and files from earlier builds are carried over,
        /// so a tester's Lastys ID survives an app update.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lastysIDByPhone = try c.decodeIfPresent([String: LastysID].self, forKey: .lastysIDByPhone) ?? [:]
            people = try c.decodeIfPresent([String: Person].self, forKey: .people) ?? [:]
            scans = try c.decodeIfPresent([String: ScanRecord].self, forKey: .scans) ?? [:]
            requests = try c.decodeIfPresent([String: RequestRecord].self, forKey: .requests) ?? [:]
            endings = try c.decodeIfPresent([String: EndingRecord].self, forKey: .endings) ?? [:]
            let earlierProfiles = try c.decodeIfPresent([String: EarlierProfile].self, forKey: .profileByLastysID) ?? [:]
            for id in lastysIDByPhone.values where people[id.personalID] == nil {
                let profile = earlierProfiles[id.personalID]
                people[id.personalID] = Person(
                    lastysID: id, createdAt: Self.notYetKnown, nickname: profile?.nickname ?? "", photo: profile?.photo
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(lastysIDByPhone, forKey: .lastysIDByPhone)
            try c.encode(people, forKey: .people)
            try c.encode(scans, forKey: .scans)
            try c.encode(requests, forKey: .requests)
            try c.encode(endings, forKey: .endings)
        }

        private enum CodingKeys: String, CodingKey {
            case lastysIDByPhone, people, scans, requests, endings
            case profileByLastysID // written by the build from ticket #3
        }

        private struct EarlierProfile: Codable {
            var nickname: String
            var photo: Data?
        }
    }

    var state: State
    private let fileURL: URL?
    let now: @Sendable () -> Date

    /// - Parameters:
    ///   - fileURL: where to keep Trustee's state between launches; nil keeps it in memory only.
    ///   - now: Trustee's clock.
    public init(savingTo fileURL: URL? = nil, now: @escaping @Sendable () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
        var loaded = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(State.self, from: $0) }
            ?? State()
        // A Lastys ID carried over from an earlier build starts aging now, and keeps that date.
        let carriedOver = loaded.people.filter { $0.value.createdAt == State.notYetKnown }.map(\.key)
        for personalID in carriedOver { loaded.people[personalID]?.createdAt = now() }
        state = loaded
        if !carriedOver.isEmpty { Self.write(loaded, to: fileURL) }
    }

    public nonisolated func client(forPhone phone: String) -> TrusteeClient {
        Client(trustee: self, phone: phone)
    }

    // MARK: Lastys ID

    func createLastysID(phone: String) throws -> NewLastysID {
        // ADR 0001: a device that already holds a Lastys ID cannot create another.
        guard state.lastysIDByPhone[phone] == nil else { throw TrusteeError.phoneAlreadyHasLastysID }
        var id = LastysID(personalID: Self.randomPersonalID())
        while state.people[id.personalID] != nil { id = LastysID(personalID: Self.randomPersonalID()) }
        state.lastysIDByPhone[phone] = id
        state.people[id.personalID] = Person(lastysID: id, createdAt: now())
        save()
        return NewLastysID(lastysID: id, recoveryCode: Self.randomRecoveryCode())
    }

    func updateProfile(phone: String, nickname: String, photo: Data?) throws {
        let id = try lastysID(of: phone)
        state.people[id.personalID]?.nickname = nickname
        state.people[id.personalID]?.photo = photo
        save()
    }

    func relationshipStatus(phone: String) throws -> RelationshipStatus {
        let me = try person(of: phone)
        guard let partnerID = me.partner, let partner = state.people[partnerID], let since = me.relationshipSince else {
            if let until = me.coolingOffUntil, until > now() { return .coolingOff(until: until) }
            return .none
        }
        return .active(partnerNickname: partner.nickname, since: since, stage: stage(of: me))
    }

    // MARK: Scan

    func scan(phone: String, payload: String) throws -> ScanResult {
        let scanner = try person(of: phone)
        guard let token = LastysQRToken(parsing: payload) else { throw TrusteeError.notALastysQR }
        guard let scanned = state.people[token.personalID],
              let key = publicKey(ofPhoneHolding: scanned.lastysID),
              token.isSigned(by: key)
        else { throw TrusteeError.forgedQR }
        let currentMinute = LastysQRToken.minute(containing: now())
        // A minute ahead is allowed too, for a showing phone whose clock runs slightly fast.
        guard (currentMinute - Int64(Self.qrMinutesAccepted)...currentMinute + 1).contains(token.minute) else {
            throw TrusteeError.expiredQR
        }
        let scanID = UUID().uuidString
        state.scans[scanID] = ScanRecord(scanner: scanner.lastysID.personalID, scanned: token.personalID, at: now())
        save()
        return ScanResult(
            scanID: scanID,
            nickname: scanned.nickname,
            photo: scanned.photo,
            status: scanned.partner == nil ? .single : .taken,
            idAgeDays: Int(now().timeIntervalSince(scanned.createdAt) / 86_400),
            phoneTransferCount: scanned.phoneTransferCount,
            relationshipHistory: scanned.shareLevel == .statusAndHistory ? scanned.pastRelationships : nil,
            requestBlock: requestBlock(from: scanner, to: scanned)
        )
    }

    // MARK: Helpers

    func lastysID(of phone: String) throws -> LastysID {
        guard let id = state.lastysIDByPhone[phone] else { throw TrusteeError.noLastysID }
        return id
    }

    func person(of phone: String) throws -> Person {
        let id = try lastysID(of: phone)
        guard let person = state.people[id.personalID] else { throw TrusteeError.noLastysID }
        return person
    }

    private func publicKey(ofPhoneHolding id: LastysID) -> P256.Signing.PublicKey? {
        guard let phone = state.lastysIDByPhone.first(where: { $0.value == id })?.key,
              let keyData = Data(base64Encoded: phone)
        else { return nil }
        return try? P256.Signing.PublicKey(compressedRepresentation: keyData)
    }

    func save() {
        Self.write(state, to: fileURL)
    }

    private static func write(_ state: State, to fileURL: URL?) {
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

        func scan(_ payload: String) async throws -> ScanResult {
            try await trustee.scan(phone: phone, payload: payload)
        }

        func sendRelationshipRequest(scanID: String) async throws -> RelationshipRequest {
            try await trustee.sendRelationshipRequest(phone: phone, scanID: scanID)
        }

        func relationshipRequest(id: String) async throws -> RelationshipRequest {
            try await trustee.relationshipRequest(phone: phone, id: id)
        }

        func respondToRelationshipRequest(id: String, accept: Bool) async throws {
            try await trustee.respondToRelationshipRequest(phone: phone, id: id, accept: accept)
        }

        func sendEndRequest() async throws {
            try await trustee.sendEndRequest(phone: phone)
        }

        func withdrawEndRequest() async throws {
            try await trustee.withdrawEndRequest(phone: phone)
        }

        func respondToEndRequest(agree: Bool) async throws {
            try await trustee.respondToEndRequest(phone: phone, agree: agree)
        }

        func escalateToTeamReview() async throws {
            try await trustee.escalateToTeamReview(phone: phone)
        }

        func reportSafetyConcern() async throws {
            try await trustee.reportSafetyConcern(phone: phone)
        }
    }
}
