import Foundation

/// Invite links: a Relationship request delivered by link, under the same rules (ADR 0004).
/// This is the sender's side; accepting and declining come with #39.
extension FakeTrustee {
    struct InviteRecord: Codable {
        enum Status: String, Codable {
            case waiting
            case cancelled
        }

        var from: String
        var createdAt: Date
        var status: Status
    }

    func createInviteLink(phone: String) throws -> InviteLink {
        let sender = try person(of: phone)
        if sender.partner != nil { throw TrusteeError.youAreTaken }
        if let until = sender.coolingOffUntil, until > now() { throw TrusteeError.youAreCoolingOff }
        if waitingInvite(from: sender.lastysID.personalID) != nil { throw TrusteeError.inviteAlreadyWaiting }
        var code = Self.randomInviteCode()
        while state.invites[code] != nil { code = Self.randomInviteCode() }
        state.invites[code] = InviteRecord(from: sender.lastysID.personalID, createdAt: now(), status: .waiting)
        save()
        return link(code: code, createdAt: now())
    }

    func myInviteLink(phone: String) throws -> InviteLink? {
        let sender = try lastysID(of: phone)
        return waitingInvite(from: sender.personalID).map { link(code: $0.code, createdAt: $0.record.createdAt) }
    }

    func cancelInviteLink(phone: String) throws {
        let sender = try lastysID(of: phone)
        guard let waiting = waitingInvite(from: sender.personalID) else { throw TrusteeError.noInviteWaiting }
        state.invites[waiting.code]?.status = .cancelled
        save()
    }

    /// The sender's Invite link that can still be used: waiting and less than 7 days old.
    private func waitingInvite(from personalID: String) -> (code: String, record: InviteRecord)? {
        state.invites
            .first { $0.value.from == personalID && $0.value.status == .waiting && now() < expiry(of: $0.value.createdAt) }
            .map { (code: $0.key, record: $0.value) }
    }

    private func expiry(of createdAt: Date) -> Date {
        createdAt.addingTimeInterval(Double(InviteLink.daysValid) * 86_400)
    }

    private func link(code: String, createdAt: Date) -> InviteLink {
        InviteLink(code: code, expiresAt: expiry(of: createdAt))
    }

    /// Eight characters, leaving out I and O so they can't be misread as 1 and 0.
    private static func randomInviteCode() -> String {
        let alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}
