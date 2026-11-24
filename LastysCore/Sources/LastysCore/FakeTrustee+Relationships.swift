import Foundation

/// Relationship requests and Relationships. A Lastys ID has at most one active Relationship (see GLOSSARY.md).
extension FakeTrustee {
    /// How long after a Scan the scanner may still send that person a Relationship request.
    public static let scanMinutesValidForRequest = 10

    /// Why `scanner` can't send `scanned` a Relationship request right now, if they can't.
    func requestBlock(from scanner: Person, to scanned: Person) -> RelationshipRequestBlock? {
        if scanner.lastysID == scanned.lastysID { return .thatIsYou }
        if scanner.partner != nil { return .youAreTaken }
        if let until = scanner.coolingOffUntil, until > now() { return .youAreCoolingOff(until: until) }
        if scanned.partner != nil { return .theyAreTaken }
        return nil
    }

    func sendRelationshipRequest(phone: String, scanID: String) throws -> RelationshipRequest {
        let sender = try person(of: phone)
        guard let scan = state.scans[scanID], scan.scanner == sender.lastysID.personalID,
              let receiver = state.people[scan.scanned]
        else { throw TrusteeError.scanRequired }
        guard now().timeIntervalSince(scan.at) <= Double(Self.scanMinutesValidForRequest * 60) else {
            throw TrusteeError.scanTooOld
        }
        switch requestBlock(from: sender, to: receiver) {
        case .thatIsYou: throw TrusteeError.thatIsYou
        case .youAreTaken: throw TrusteeError.youAreTaken
        case .youAreCoolingOff: throw TrusteeError.youAreCoolingOff
        case .theyAreTaken: throw TrusteeError.theyAreTaken
        case nil: break
        }
        let id = UUID().uuidString
        state.requests[id] = RequestRecord(
            from: sender.lastysID.personalID, to: receiver.lastysID.personalID,
            status: RelationshipRequest.Status.pending.rawValue, sentAt: now()
        )
        save()
        return try relationshipRequest(phone: phone, id: id)
    }

    func relationshipRequest(phone: String, id: String) throws -> RelationshipRequest {
        let sender = try lastysID(of: phone)
        guard let request = state.requests[id], request.from == sender.personalID else {
            throw TrusteeError.requestNotFound
        }
        return RelationshipRequest(
            id: id,
            toNickname: state.people[request.to]?.nickname ?? "",
            status: RelationshipRequest.Status(rawValue: request.status) ?? .expired
        )
    }

    /// Accepting checks both sides before anything changes, so a Lastys ID can never end up
    /// in two Relationships, whichever request is accepted first.
    func respondToRelationshipRequest(phone: String, id: String, accept: Bool) throws {
        let receiver = try person(of: phone)
        guard let request = state.requests[id], request.to == receiver.lastysID.personalID,
              let sender = state.people[request.from]
        else { throw TrusteeError.requestNotFound }
        let pending = RelationshipRequest.Status.pending.rawValue

        guard accept else {
            guard request.status == pending else { throw TrusteeError.requestNotPending }
            // Declining changes nothing else: no Cooling-off period starts for either side.
            state.requests[id]?.status = RelationshipRequest.Status.declined.rawValue
            save()
            return
        }
        if receiver.partner != nil { throw TrusteeError.youAreTaken }
        if let until = receiver.coolingOffUntil, until > now() { throw TrusteeError.youAreCoolingOff }
        if sender.partner != nil { throw TrusteeError.theyAreTaken }
        if let until = sender.coolingOffUntil, until > now() { throw TrusteeError.theyAreCoolingOff }
        guard request.status == pending else { throw TrusteeError.requestNotPending }

        let since = now()
        state.people[sender.lastysID.personalID]?.partner = receiver.lastysID.personalID
        state.people[sender.lastysID.personalID]?.relationshipSince = since
        state.people[receiver.lastysID.personalID]?.partner = sender.lastysID.personalID
        state.people[receiver.lastysID.personalID]?.relationshipSince = since
        state.requests[id]?.status = RelationshipRequest.Status.accepted.rawValue
        // Every other request still waiting on either of them is no longer possible.
        let partners: Set = [sender.lastysID.personalID, receiver.lastysID.personalID]
        for (otherID, other) in state.requests
        where otherID != id && other.status == pending && (partners.contains(other.from) || partners.contains(other.to)) {
            state.requests[otherID]?.status = RelationshipRequest.Status.expired.rawValue
        }
        save()
    }
}
