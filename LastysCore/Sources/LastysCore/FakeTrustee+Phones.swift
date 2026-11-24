import Foundation

/// Moving a Lastys ID to another phone: a Phone transfer from a working phone, or a Recovery with the
/// Recovery code after losing one. The key is never copied: the Lastys ID moves onto the new phone's
/// own key and the old phone is retired (ADR 0003).
extension FakeTrustee {
    struct TransferRecord: Codable {
        var personalID: String
        /// The old phone's private data, sealed with a key only the QR carries. Trustee never reads it.
        var sealedBundle: Data
        var expiresAt: Date
    }

    struct RecoveryRecord: Codable {
        /// The new phone the Lastys ID will move to.
        var newPhone: String
        var completesAt: Date
        var cancelled = false

        init(newPhone: String, completesAt: Date) {
            self.newPhone = newPhone
            self.completesAt = completesAt
        }

        /// A record saved before cancelling existed loads as not cancelled.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            newPhone = try c.decode(String.self, forKey: .newPhone)
            completesAt = try c.decode(Date.self, forKey: .completesAt)
            cancelled = try c.decodeIfPresent(Bool.self, forKey: .cancelled) ?? false
        }
    }

    // MARK: Phone transfer

    func startPhoneTransfer(phone: String, sealedBundle: Data) throws -> PhoneTransferOffer {
        let me = try person(of: phone)
        if let last = me.lastTransferAt,
           now() < last.addingTimeInterval(Double(PhoneTransferOffer.daysBetweenTransfers) * 86_400) {
            throw TrusteeError.transferTooSoon
        }
        let code = Self.randomTransferCode()
        let expiresAt = now().addingTimeInterval(Double(PhoneTransferOffer.validMinutes) * 60)
        // Only the newest code works: two open codes must never mean two Phone transfers.
        state.transfers = state.transfers.filter { $0.value.personalID != me.lastysID.personalID }
        state.transfers[code] = TransferRecord(
            personalID: me.lastysID.personalID, sealedBundle: sealedBundle, expiresAt: expiresAt
        )
        save()
        return PhoneTransferOffer(code: code, expiresAt: expiresAt)
    }

    func completePhoneTransfer(phone: String, code: String) throws -> TransferredLastysID {
        guard state.lastysIDByPhone[phone] == nil else { throw TrusteeError.phoneAlreadyHasLastysID }
        guard let transfer = state.transfers[code], state.people[transfer.personalID] != nil else {
            throw TrusteeError.transferCodeInvalid
        }
        guard now() < transfer.expiresAt else { throw TrusteeError.transferCodeExpired }
        if let last = state.people[transfer.personalID]?.lastTransferAt,
           now() < last.addingTimeInterval(Double(PhoneTransferOffer.daysBetweenTransfers) * 86_400) {
            throw TrusteeError.transferTooSoon
        }
        move(transfer.personalID, to: phone)
        state.people[transfer.personalID]?.lastTransferAt = now()
        tellPartner(of: transfer.personalID, .partnerChangedPhone)
        save()
        return TransferredLastysID(lastysID: LastysID(personalID: transfer.personalID), sealedBundle: transfer.sealedBundle)
    }

    // MARK: Recovery

    /// From a phone without a Lastys ID: checks the code against every stored hash and starts the 7-day
    /// wait. The phone holding the Lastys ID, and its Partner, are told.
    func startRecovery(phone: String, recoveryCode: String) throws -> RecoveryStarted {
        guard state.lastysIDByPhone[phone] == nil else { throw TrusteeError.phoneAlreadyHasLastysID }
        let hash = Self.hash(recoveryCode: recoveryCode)
        guard let person = state.people.values.first(where: { $0.recoveryCodeHash == hash }) else {
            throw TrusteeError.wrongRecoveryCode
        }
        let id = person.lastysID.personalID
        let completesAt = now().addingTimeInterval(Double(RecoveryStarted.waitDays) * 86_400)
        state.recoveries[id] = RecoveryRecord(newPhone: phone, completesAt: completesAt)
        state.notices[id, default: []].append(.recoveryStarted)
        tellPartner(of: id, .partnerStartedRecovery)
        save()
        return RecoveryStarted(completesAt: completesAt)
    }

    func recoveryStatus(phone: String) -> RecoveryStatus {
        guard let record = state.recoveries.values.first(where: { $0.newPhone == phone }) else { return .notStarted }
        if record.cancelled { return .cancelled }
        return now() >= record.completesAt ? .ready : .waiting(completesAt: record.completesAt)
    }

    func completeRecovery(phone: String) throws -> NewLastysID {
        guard let (id, record) = state.recoveries.first(where: { $0.value.newPhone == phone }), !record.cancelled else {
            throw TrusteeError.noRecovery
        }
        guard now() >= record.completesAt else { throw TrusteeError.recoveryNotReady }
        guard state.people[id] != nil, state.lastysIDByPhone[phone] == nil else { throw TrusteeError.noRecovery }
        move(id, to: phone)
        // The code that was just used is spent: the person gets a new one.
        let code = Self.randomRecoveryCode()
        state.people[id]?.recoveryCodeHash = Self.hash(recoveryCode: code)
        save()
        return NewLastysID(lastysID: LastysID(personalID: id), recoveryCode: code)
    }

    func cancelRecovery(phone: String) throws {
        let id = try lastysID(of: phone).personalID
        guard let record = state.recoveries[id], !record.cancelled else { throw TrusteeError.noRecovery }
        state.recoveries[id]?.cancelled = true
        // Whoever started it has the Recovery code: retire it, so they can't simply start again.
        // The owner makes a new one from Me.
        state.people[id]?.recoveryCodeHash = nil
        save()
    }

    // MARK: Notices

    /// Each notice is delivered once.
    func notices(phone: String) throws -> [Notice] {
        let id = try lastysID(of: phone).personalID
        let pending = state.notices[id] ?? []
        state.notices[id] = nil
        if !pending.isEmpty { save() }
        return pending
    }

    // MARK: Helpers

    /// The Lastys ID now lives on `phone`'s own key; every other phone that held it is retired.
    private func move(_ personalID: String, to phone: String) {
        state.transfers = state.transfers.filter { $0.value.personalID != personalID }
        if state.recoveries[personalID]?.newPhone == phone {
            state.recoveries[personalID] = nil
        } else {
            state.recoveries[personalID]?.cancelled = true
        }
        state.lastysIDByPhone = state.lastysIDByPhone.filter { $0.value.personalID != personalID }
        state.lastysIDByPhone[phone] = LastysID(personalID: personalID)
        state.people[personalID]?.phoneTransferCount += 1
    }

    /// Eight characters, like a Recovery code's blocks; a transfer code lives 5 minutes.
    private static func randomTransferCode() -> String {
        String(randomRecoveryCode().prefix(9))
    }

    private func tellPartner(of personalID: String, _ notice: Notice) {
        guard let partner = state.people[personalID]?.partner else { return }
        state.notices[partner, default: []].append(notice)
    }
}
