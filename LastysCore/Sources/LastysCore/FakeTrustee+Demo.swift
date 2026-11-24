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

    /// Demo: the sample person a Relationship request went to accepts or declines it, as their phone would.
    public func demoRespondToRelationshipRequest(id: String, accept: Bool) throws {
        guard let receiver = state.requests[id]?.to,
              let demo = DemoPerson.allCases.first(where: { $0.personalID == receiver })
        else { throw TrusteeError.requestNotFound }
        try respondToRelationshipRequest(phone: demo.key.trusteeID, id: id, accept: accept)
    }

    /// Demo: the Partner of `personalID` agrees to or declines their End request, as the Partner's phone would.
    public func demoPartnerRespondsToEndRequest(of personalID: String, agree: Bool) throws {
        try respondToEndRequest(phone: try phoneOfPartner(of: personalID), agree: agree)
    }

    /// Demo: the Partner of `personalID` asks to end the Relationship, as the Partner's phone would.
    public func demoPartnerSendsEndRequest(of personalID: String) throws {
        try sendEndRequest(phone: try phoneOfPartner(of: personalID))
    }

    /// Demo: the Partner of `personalID` reports a safety concern, as the Partner's phone would.
    public func demoPartnerReportsSafetyConcern(of personalID: String) throws {
        try reportSafetyConcern(phone: try phoneOfPartner(of: personalID))
    }

    /// Demo: the 7 days to answer `personalID`'s End request run out with no answer.
    public func demoNoAnswerFor7Days(toEndRequestOf personalID: String) throws {
        guard let partner = state.people[personalID]?.partner,
              let sentAt = state.endings[Self.relationshipKey(personalID, partner)]?.endRequestSentAt
        else { throw TrusteeError.notAllowedNow }
        state.endings[Self.relationshipKey(personalID, partner)]?.endRequestSentAt =
            sentAt.addingTimeInterval(-Double(EndRequest.daysToAnswer) * 86_400)
        save()
    }

    /// Demo: `personalID`'s Cooling-off period is over now.
    public func demoSkipCoolingOff(of personalID: String) throws {
        guard state.people[personalID]?.coolingOffUntil != nil else { throw TrusteeError.notAllowedNow }
        state.people[personalID]?.coolingOffUntil = nil
        save()
    }

    private func phoneOfPartner(of personalID: String) throws -> String {
        guard let partner = state.people[personalID]?.partner,
              let phone = state.lastysIDByPhone.first(where: { $0.value.personalID == partner })?.key
        else { throw TrusteeError.noRelationship }
        return phone
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
            // Sokha's Partner, Bopha, has no phone in the demo: nobody can Scan or act as her.
            let bophaID = LastysID(personalID: "LT-BPHA-1234")
            let since = daysAgo(150)
            var bopha = Person(lastysID: bophaID, createdAt: daysAgo(300), nickname: "Bopha")
            bopha.partner = demo.personalID
            bopha.relationshipSince = since
            state.people[bophaID.personalID] = bopha
            person.createdAt = daysAgo(200)
            person.partner = bophaID.personalID
            person.relationshipSince = since
        }
        state.lastysIDByPhone[demo.key.trusteeID] = id
        state.people[demo.personalID] = person
        save()
    }
}
#endif
