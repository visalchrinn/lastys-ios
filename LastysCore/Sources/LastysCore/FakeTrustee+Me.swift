import Crypto
import Foundation

/// The Me tab: Share level, details of my Lastys ID, Who scanned me, and the Recovery code.
extension FakeTrustee {
    struct RecoveryRecord: Codable {
        /// The new phone the Lastys ID will move to.
        var newPhone: String
        var completesAt: Date
    }

    func setShareLevel(phone: String, level: ShareLevel) throws {
        let id = try lastysID(of: phone)
        state.people[id.personalID]?.shareLevel = level
        save()
    }

    func myLastysIDDetails(phone: String) throws -> MyLastysIDDetails {
        let me = try person(of: phone)
        return MyLastysIDDetails(
            createdAt: me.createdAt, phoneTransferCount: me.phoneTransferCount,
            shareLevel: me.shareLevel, hasRecoveryCode: me.recoveryCodeHash != nil
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

    /// Checks the code against every Lastys ID's stored hash and records a Recovery to the asking phone.
    func startRecovery(phone: String, recoveryCode: String) throws -> RecoveryStarted {
        let hash = Self.hash(recoveryCode: recoveryCode)
        guard let person = state.people.values.first(where: { $0.recoveryCodeHash == hash }) else {
            throw TrusteeError.wrongRecoveryCode
        }
        let completesAt = now().addingTimeInterval(Double(RecoveryStarted.waitDays) * 86_400)
        state.recoveries[person.lastysID.personalID] = RecoveryRecord(newPhone: phone, completesAt: completesAt)
        save()
        return RecoveryStarted(completesAt: completesAt)
    }

    /// The Recovery code's SHA-256, ignoring case, spaces and dashes so a typed code matches.
    static func hash(recoveryCode: String) -> String {
        let normalised = recoveryCode.uppercased().filter { $0.isLetter || $0.isNumber }
        return SHA256.hash(data: Data(normalised.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
