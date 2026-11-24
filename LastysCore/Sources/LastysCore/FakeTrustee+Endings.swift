import Foundation

/// Ending a Relationship, which never happens one-sidedly (ADR 0002): the other Partner agrees,
/// or the Lastys team decides after a Team review. Each transition below is the only way to its stage.
extension FakeTrustee {
    /// After a Relationship ends, both former Partners wait this long before any new Relationship request.
    public static let coolingOffDays = 7

    struct EndingRecord: Codable {
        /// Personal ID of the Partner who sent the End request, if one is open.
        var endRequestFrom: String?
        var endRequestSentAt: Date?
        var declined = false
        var reviewReason: TeamReview.Reason?
        var reviewSince: Date?
    }

    /// The same key whichever Partner asks.
    static func relationshipKey(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "|")
    }

    /// The stage of `person`'s active Relationship, from their side.
    func stage(of person: Person) -> RelationshipStage {
        guard let partner = person.partner,
              let ending = state.endings[Self.relationshipKey(person.lastysID.personalID, partner)]
        else { return .together }
        if let reason = ending.reviewReason, let since = ending.reviewSince {
            return .inTeamReview(TeamReview(reason: reason, since: since))
        }
        if let from = ending.endRequestFrom, let sentAt = ending.endRequestSentAt {
            return .ending(EndRequest(sentByMe: from == person.lastysID.personalID, sentAt: sentAt, declined: ending.declined))
        }
        return .together
    }

    func sendEndRequest(phone: String) throws {
        let (me, partner) = try partners(of: phone)
        guard try stage(ofPhone: phone) == .together else { throw TrusteeError.notAllowedNow }
        state.endings[Self.relationshipKey(me, partner)] = EndingRecord(endRequestFrom: me, endRequestSentAt: now())
        save()
    }

    func withdrawEndRequest(phone: String) throws {
        let (me, partner) = try partners(of: phone)
        guard case .ending(let request) = try stage(ofPhone: phone), request.sentByMe else { throw TrusteeError.notAllowedNow }
        state.endings[Self.relationshipKey(me, partner)] = nil
        save()
    }

    func respondToEndRequest(phone: String, agree: Bool) throws {
        let (me, partner) = try partners(of: phone)
        guard case .ending(let request) = try stage(ofPhone: phone), !request.sentByMe, !request.declined else {
            throw TrusteeError.notAllowedNow
        }
        if agree {
            end(me, partner)
        } else {
            state.endings[Self.relationshipKey(me, partner)]?.declined = true
        }
        save()
    }

    func escalateToTeamReview(phone: String) throws {
        let (me, partner) = try partners(of: phone)
        guard case .ending(let request) = try stage(ofPhone: phone), request.sentByMe else { throw TrusteeError.notAllowedNow }
        guard request.declined || now() >= request.answerBy else { throw TrusteeError.cannotEscalateYet }
        startTeamReview(me, partner, reason: .endRequest)
        save()
    }

    /// At any stage, even during an End request or a Team review for it.
    func reportSafetyConcern(phone: String) throws {
        let (me, partner) = try partners(of: phone)
        if case .inTeamReview(let review) = try stage(ofPhone: phone), review.reason == .safetyConcern { return }
        startTeamReview(me, partner, reason: .safetyConcern)
        save()
    }

    /// The Lastys team's decision at the end of a Team review: the staff console in Phase B.
    /// Not part of `TrusteeClient`, so no Partner's phone can reach it.
    public func teamDecides(aboutRelationshipOf personalID: String, endIt: Bool) throws {
        guard let person = state.people[personalID], let partner = person.partner else { throw TrusteeError.noRelationship }
        guard case .inTeamReview = stage(of: person) else { throw TrusteeError.notAllowedNow }
        if endIt {
            end(personalID, partner)
        } else {
            state.endings[Self.relationshipKey(personalID, partner)] = nil
        }
        save()
    }

    // MARK: Helpers

    private func partners(of phone: String) throws -> (me: String, partner: String) {
        let me = try person(of: phone)
        guard let partner = me.partner else { throw TrusteeError.noRelationship }
        return (me.lastysID.personalID, partner)
    }

    private func stage(ofPhone phone: String) throws -> RelationshipStage {
        stage(of: try person(of: phone))
    }

    private func startTeamReview(_ a: String, _ b: String, reason: TeamReview.Reason) {
        var ending = state.endings[Self.relationshipKey(a, b)] ?? EndingRecord()
        ending.reviewReason = reason
        ending.reviewSince = now()
        state.endings[Self.relationshipKey(a, b)] = ending
    }

    /// Ends the Relationship for both: each keeps it in their history as months only,
    /// and both enter the Cooling-off period.
    private func end(_ a: String, _ b: String) {
        let ended = now()
        splitSharedMoments(a, b)
        let coolingOffUntil = ended.addingTimeInterval(Double(Self.coolingOffDays) * 86_400)
        for (me, partner) in [(a, b), (b, a)] {
            guard var person = state.people[me], person.partner == partner else { continue }
            if let since = person.relationshipSince {
                person.pastRelationships.append(PastRelationship(started: Self.month(of: since), ended: Self.month(of: ended)))
            }
            person.partner = nil
            person.relationshipSince = nil
            person.coolingOffUntil = coolingOffUntil
            state.people[me] = person
        }
        state.endings[Self.relationshipKey(a, b)] = nil
    }

    private static func month(of date: Date) -> YearMonth {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Phnom_Penh") ?? .current
        let parts = calendar.dateComponents([.year, .month], from: date)
        return YearMonth(year: parts.year ?? 0, month: parts.month ?? 0)
    }
}
