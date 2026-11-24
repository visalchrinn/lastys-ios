import Crypto
import Foundation

/// The Me tab: Share level, details of my Lastys ID, Who scanned me, and the Recovery code.
extension FakeTrustee {
    func setShareLevel(phone: String, level: ShareLevel) throws {
        let id = try lastysID(of: phone)
        state.people[id.personalID]?.shareLevel = level
        save()
    }

    func myLastysIDDetails(phone: String) throws -> MyLastysIDDetails {
        let me = try person(of: phone)
        return MyLastysIDDetails(
            createdAt: me.createdAt, phoneTransferCount: me.phoneTransferCount,
            shareLevel: me.shareLevel, hasRecoveryCode: me.recoveryCodeHash != nil,
            recoveryCompletesAt: state.recoveries[me.lastysID.personalID].flatMap { $0.cancelled ? nil : $0.completesAt }
        )
    }

    /// Only the times. Who scanned is kept for the Lastys team alone, for abuse investigations.
    func whoScannedMe(phone: String) throws -> [Date] {
        let me = try lastysID(of: phone).personalID
        return state.scans.values.filter { $0.scanned == me }.map(\.at).sorted(by: >)
    }

    func newRecoveryCode(phone: String) throws -> String {
        let id = try lastysID(of: phone)
        let code = Self.randomRecoveryCode()
        state.people[id.personalID]?.recoveryCodeHash = Self.hash(recoveryCode: code)
        // A Recovery already started with the old code (perhaps a leaked one) stops too.
        state.recoveries[id.personalID] = nil
        save()
        return code
    }

    /// Removes the Lastys ID and everything about it: Scans either way, Relationship requests, Shared
    /// Moment copies and any pending Recovery. A former Partner keeps their own copies.
    func deleteMyData(phone: String) throws {
        let me = try person(of: phone)
        guard me.partner == nil else { throw TrusteeError.relationshipNotOver }
        let id = me.lastysID.personalID
        state.lastysIDByPhone = state.lastysIDByPhone.filter { $0.value.personalID != id }
        state.people[id] = nil
        state.scans = state.scans.filter { $0.value.scanner != id && $0.value.scanned != id }
        state.requests = state.requests.filter { $0.value.from != id && $0.value.to != id }
        state.sharedMoments[id] = nil
        state.formerSharedMoments[id] = nil
        state.recoveries[id] = nil
        state.transfers = state.transfers.filter { $0.value.personalID != id }
        save()
    }

    /// The Recovery code's SHA-256, ignoring case, spaces and dashes so a typed code matches.
    static func hash(recoveryCode: String) -> String {
        let normalised = recoveryCode.uppercased().filter { $0.isLetter || $0.isNumber }
        return SHA256.hash(data: Data(normalised.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
