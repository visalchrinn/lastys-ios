#if DEBUG
import Crypto
import Foundation

/// Demo: sample people nearby, so a tester can Scan someone with one phone.
/// Exists only in Debug builds, so a Release IPA cannot reach it.
public enum DemoPerson: String, CaseIterable, Sendable {
    /// Single, with a year-old Lastys ID, and shares Status + history.
    case dara
    /// A brand-new Lastys ID that shares Status only.
    case vanna
    /// Taken.
    case sokha

    public var nickname: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    fileprivate var personalID: String {
        switch self {
        case .dara: return "LT-DARA-2024"
        case .vanna: return "LT-VANN-A001"
        case .sokha: return "LT-SKHA-7777"
        }
    }

    /// The same key on every launch, so the fake never has to store a demo person's private key.
    fileprivate var key: SoftwarePhoneKey {
        let seed = Data(SHA256.hash(data: Data("lastys-demo-\(rawValue)".utf8)))
        return try! SoftwarePhoneKey(rawRepresentation: seed)
    }
}

extension FakeTrustee {
    /// Demo: the live Lastys QR of a sample person nearby, as their phone would show it at `date`.
    /// Adds the person to Trustee the first time.
    public func demoLastysQR(of person: DemoPerson, at date: Date) throws -> String {
        addIfMissing(person)
        return try LastysQRToken(personalID: person.personalID, at: date, signedBy: person.key).text
    }

    private func addIfMissing(_ demo: DemoPerson) {
        guard state.people[demo.personalID] == nil else { return }
        let id = LastysID(personalID: demo.personalID)
        let daysAgo = { (days: Double) in self.now().addingTimeInterval(-days * 86_400) }
        var person = Person(lastysID: id, createdAt: now(), nickname: demo.nickname)
        switch demo {
        case .dara:
            person.createdAt = daysAgo(400)
            person.shareLevel = .statusAndHistory
            person.phoneTransferCount = 1
            person.pastRelationships = [
                PastRelationship(started: YearMonth(year: 2022, month: 3), ended: YearMonth(year: 2023, month: 1)),
                PastRelationship(started: YearMonth(year: 2023, month: 6), ended: YearMonth(year: 2024, month: 2)),
            ]
        case .vanna:
            break
        case .sokha:
            person.createdAt = daysAgo(200)
            person.partner = "LT-BPHA-1234"
        }
        state.lastysIDByPhone[demo.key.trusteeID] = id
        state.people[demo.personalID] = person
        save()
    }
}
#endif
