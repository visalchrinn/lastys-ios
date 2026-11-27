import Foundation

/// Invite links: a Relationship request delivered by link, under the same rules (ADR 0004).
/// Each link is backed by a Relationship request with no receiver until someone opens it, so accepting
/// goes through the same path as accepting after a Scan, and a link stops working the moment its request
/// can't be accepted any more.
extension FakeTrustee {
    struct InviteRecord: Codable {
        enum Status: String, Codable {
            case waiting
            case cancelled
            /// Accepted or declined: one person only.
            case used
        }

        var from: String
        var createdAt: Date
        var status: Status
        /// The Relationship request behind the link. Links from the build before #39 have none until next read.
        var requestID: String?
    }

    // MARK: Sender

    func createInviteLink(phone: String) throws -> InviteLink {
        let sender = try person(of: phone)
        if sender.partner != nil { throw TrusteeError.youAreTaken }
        if let until = sender.coolingOffUntil, until > now() { throw TrusteeError.youAreCoolingOff }
        if usableInvite(from: sender.lastysID.personalID) != nil { throw TrusteeError.inviteAlreadyWaiting }
        var code = Self.randomInviteCode()
        while state.invites[code] != nil { code = Self.randomInviteCode() }
        state.invites[code] = InviteRecord(
            from: sender.lastysID.personalID, createdAt: now(), status: .waiting,
            requestID: newInviteRequest(from: sender.lastysID.personalID)
        )
        save()
        return try link(code: code)
    }

    func myInviteLink(phone: String) throws -> InviteLink? {
        let sender = try lastysID(of: phone)
        guard let code = usableInvite(from: sender.personalID) else { return nil }
        return try link(code: code)
    }

    func cancelInviteLink(phone: String) throws {
        let sender = try lastysID(of: phone)
        guard let code = usableInvite(from: sender.personalID) else { throw TrusteeError.noInviteWaiting }
        state.invites[code]?.status = .cancelled
        if let requestID = state.invites[code]?.requestID {
            state.requests[requestID]?.status = RelationshipRequest.Status.expired.rawValue
        }
        save()
    }

    // MARK: Receiver

    func receivedInvite(phone: String, code: String) throws -> ReceivedInvite {
        let receiver = try person(of: phone)
        let invite = try usableInvite(code: code, openedBy: receiver)
        return ReceivedInvite(code: code, senderNickname: state.people[invite.from]?.nickname ?? "")
    }

    /// Accepting checks every Relationship request rule on both sides, through the same path as after a Scan.
    func acceptInvite(phone: String, code: String) throws {
        let receiver = try person(of: phone)
        let invite = try usableInvite(code: code, openedBy: receiver)
        let requestID = invite.requestID ?? newInviteRequest(from: invite.from)
        state.invites[code]?.requestID = requestID
        state.requests[requestID]?.to = receiver.lastysID.personalID
        do {
            try respondToRelationshipRequest(phone: phone, id: requestID, accept: true)
        } catch {
            state.requests[requestID]?.to = ""
            throw error
        }
        state.invites[code]?.status = .used
        save()
    }

    /// Not now: the sender is told, and the link is used up. Nothing else changes.
    func declineInvite(phone: String, code: String) throws {
        let receiver = try person(of: phone)
        let invite = try usableInvite(code: code, openedBy: receiver)
        let requestID = invite.requestID ?? newInviteRequest(from: invite.from)
        state.invites[code]?.requestID = requestID
        state.invites[code]?.status = .used
        state.requests[requestID]?.to = receiver.lastysID.personalID
        state.requests[requestID]?.status = RelationshipRequest.Status.declined.rawValue
        save()
    }

    /// Whether the Relationship request behind an Invite link has run out its 7 days unanswered.
    func isExpiredInvite(requestID: String) -> Bool {
        state.invites.values.contains { $0.requestID == requestID && $0.status == .waiting && now() >= expiry(of: $0.createdAt) }
    }

    // MARK: Helpers

    private func usableInvite(code: String, openedBy receiver: Person) throws -> InviteRecord {
        guard let invite = state.invites[code], isUsable(invite) else { throw TrusteeError.inviteNotValid }
        if invite.from == receiver.lastysID.personalID { throw TrusteeError.thatIsYou }
        return invite
    }

    /// The code of the sender's Invite link that can still be used, if any.
    private func usableInvite(from personalID: String) -> String? {
        state.invites.first { $0.value.from == personalID && isUsable($0.value) }?.key
    }

    /// Waiting, less than 7 days old, and its Relationship request still open: not cancelled, used, or
    /// expired because the sender became Taken another way.
    private func isUsable(_ invite: InviteRecord) -> Bool {
        guard invite.status == .waiting, now() < expiry(of: invite.createdAt) else { return false }
        guard let requestID = invite.requestID else { return true }
        return state.requests[requestID]?.status == RelationshipRequest.Status.pending.rawValue
    }

    private func newInviteRequest(from personalID: String) -> String {
        let id = UUID().uuidString
        state.requests[id] = RequestRecord(
            from: personalID, to: "", status: RelationshipRequest.Status.pending.rawValue, sentAt: now()
        )
        return id
    }

    private func expiry(of createdAt: Date) -> Date {
        createdAt.addingTimeInterval(Double(InviteLink.daysValid) * 86_400)
    }

    private func link(code: String) throws -> InviteLink {
        guard var invite = state.invites[code] else { throw TrusteeError.inviteNotValid }
        if invite.requestID == nil {
            invite.requestID = newInviteRequest(from: invite.from)
            state.invites[code] = invite
            save()
        }
        return InviteLink(code: code, requestID: invite.requestID ?? "", expiresAt: expiry(of: invite.createdAt))
    }

    /// Eight characters, leaving out I and O so they can't be misread as 1 and 0.
    private static func randomInviteCode() -> String {
        let alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}
