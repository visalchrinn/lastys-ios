import Foundation

/// Shared Moments: what each Partner shares into the Relationship, and each former Partner's own copy
/// after it ends. Personal Moments never arrive here.
extension FakeTrustee {
    func setMySharedMoments(phone: String, moments: [SharedMoment]) throws {
        let me = try person(of: phone)
        guard me.partner != nil else { throw TrusteeError.noRelationship }
        state.sharedMoments[me.lastysID.personalID] = moments
        save()
    }

    func partnerSharedMoments(phone: String) throws -> [SharedMoment] {
        guard let partner = try person(of: phone).partner else { throw TrusteeError.noRelationship }
        return state.sharedMoments[partner] ?? []
    }

    func formerSharedMoments(phone: String) throws -> [SharedMoment] {
        state.formerSharedMoments[try lastysID(of: phone).personalID] ?? []
    }

    func discardFormerSharedMoments(phone: String) throws {
        state.formerSharedMoments[try lastysID(of: phone).personalID] = nil
        save()
    }

    /// When a Relationship ends, each former Partner gets their own copy of what the other shared.
    /// From then on the two copies are independent.
    func splitSharedMoments(_ a: String, _ b: String) {
        for (me, partner) in [(a, b), (b, a)] {
            let received = state.sharedMoments[partner] ?? []
            if !received.isEmpty {
                state.formerSharedMoments[me, default: []].append(contentsOf: received)
            }
        }
        state.sharedMoments[a] = nil
        state.sharedMoments[b] = nil
    }
}
