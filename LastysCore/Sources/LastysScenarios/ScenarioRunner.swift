import Foundation
import LastysCore

/// Runs a `Scenario` against a fresh fake Trustee. Each phone named in the scenario gets its own
/// key, and Trustee runs on a clock the scenario moves with `wait`.
/// Stops at the first failing step, since later steps depend on earlier ones.
public struct ScenarioRunner {
    /// Scenarios start at the same moment every time: 2026-11-29 05:00:15 UTC.
    static let start = Date(timeIntervalSince1970: 1_795_928_415)

    public init() {}

    public func run(_ scenario: Scenario) async -> [ScenarioFailure] {
        let run = Run()
        for (index, step) in scenario.steps.enumerated() {
            let number = index + 1
            let response: [String: String]
            do {
                guard let result = try await run.perform(step) else {
                    return [ScenarioFailure(step: number, message: "unknown action \"\(step.action)\"")]
                }
                response = result
            } catch let error as TrusteeError {
                response = ["error": error.code]
            } catch let error as ScenarioError {
                return [ScenarioFailure(step: number, message: error.message)]
            } catch {
                return [ScenarioFailure(step: number, message: "unexpected error \(error)")]
            }
            for (field, expected) in step.expect.sorted(by: { $0.key < $1.key }) where response[field] != expected {
                let actual = response[field].map { "\"\($0)\"" } ?? "nothing"
                return [ScenarioFailure(step: number, message: "expected \(field) = \"\(expected)\", got \(actual)")]
            }
        }
        return []
    }
}

struct ScenarioError: Error {
    let message: String
}

/// One scenario's world: its clock, its Trustee, and each phone's key and Lastys ID.
private final class Run: @unchecked Sendable {
    private let lock = NSLock()
    private var now = ScenarioRunner.start
    private lazy var trustee = FakeTrustee(now: { [unowned self] in self.lock.withLock { self.now } })
    private var keys: [String: SoftwarePhoneKey] = [:]
    private var personalIDs: [String: String] = [:]
    /// Each phone's latest Scan, and which phone it scanned.
    private var lastScan: [String: (scanID: String, of: String?)] = [:]
    /// Relationship requests sent, by sender phone then receiver phone.
    private var requestIDs: [String: [String: String]] = [:]

    private func key(of phone: String) -> SoftwarePhoneKey {
        if let key = keys[phone] { return key }
        let key = SoftwarePhoneKey()
        keys[phone] = key
        return key
    }

    /// The response fields for a step, or nil when the action is unknown.
    func perform(_ step: Scenario.Step) async throws -> [String: String]? {
        if step.action == "team-decides" { return try await teamDecides(step) }
        let client = trustee.client(forPhone: key(of: step.phone).trusteeID)
        switch step.action {
        case "create-lastys-id":
            let created = try await client.createLastysID()
            personalIDs[step.phone] = created.lastysID.personalID
            return ["personalID": created.lastysID.personalID, "recoveryCode": created.recoveryCode]
        case "update-profile":
            try await client.updateProfile(nickname: step.arguments["nickname"] ?? "", photo: nil)
            return [:]
        case "get-relationship-status":
            return try await client.relationshipStatus().fields
        case "scan":
            let result = try await client.scan(scannedPayload(step.arguments))
            lastScan[step.phone] = (result.scanID, step.arguments["qrOf"])
            return result.fields
        case "send-relationship-request":
            let scan = step.arguments["scanOf"].map { lastScan[$0] } ?? lastScan[step.phone]
            let request = try await client.sendRelationshipRequest(scanID: scan?.scanID ?? "no-scan")
            if let receiver = scan?.of { requestIDs[step.phone, default: [:]][receiver] = request.id }
            return request.fields
        case "get-relationship-request-status":
            return try await client.relationshipRequest(id: try requestID(from: step.phone, to: step.arguments["to"])).fields
        case "accept-relationship-request", "decline-relationship-request":
            let id = try requestID(from: step.arguments["from"], to: step.phone)
            try await client.respondToRelationshipRequest(id: id, accept: step.action == "accept-relationship-request")
            return [:]
        case "send-end-request":
            try await client.sendEndRequest()
            return [:]
        case "withdraw-end-request":
            try await client.withdrawEndRequest()
            return [:]
        case "agree-to-end-request", "decline-end-request":
            try await client.respondToEndRequest(agree: step.action == "agree-to-end-request")
            return [:]
        case "escalate-to-team-review":
            try await client.escalateToTeamReview()
            return [:]
        case "report-safety-concern":
            try await client.reportSafetyConcern()
            return [:]
        case "turn-on-quick-hide", "turn-off-quick-hide":
            // Quick hide lives on the phone only: it never reaches Trustee, so it can never change a Scan.
            return [:]
        case "wait":
            let minutes = Double(step.arguments["minutes"] ?? "0") ?? 0
            let days = Double(step.arguments["days"] ?? "0") ?? 0
            lock.withLock { now += minutes * 60 + days * 86_400 }
            return [:]
        default:
            return nil
        }
    }

    /// The Lastys team, not a phone: the staff console's decision after a Team review. Its `phone` gets no key.
    private func teamDecides(_ step: Scenario.Step) async throws -> [String: String] {
        guard let about = step.arguments["about"], let personalID = personalIDs[about] else {
            throw ScenarioError(message: "team-decides needs `about`, a phone that has created a Lastys ID")
        }
        try await trustee.teamDecides(aboutRelationshipOf: personalID, endIt: step.arguments["end"] == "true")
        return [:]
    }

    private func requestID(from sender: String?, to receiver: String?) throws -> String {
        guard let sender, let receiver, let id = requestIDs[sender]?[receiver] else {
            throw ScenarioError(message: "no Relationship request from \(sender ?? "?") to \(receiver ?? "?") in this scenario")
        }
        return id
    }

    /// What the scanner's camera reads: a raw `payload`, or the Lastys QR of phone `qrOf`,
    /// made `madeMinutesAgo` and signed by `signedBy` (that phone itself unless forging).
    private func scannedPayload(_ arguments: [String: String]) throws -> String {
        if let payload = arguments["payload"] { return payload }
        guard let shower = arguments["qrOf"], let personalID = personalIDs[shower] else {
            throw ScenarioError(message: "scan needs a payload, or qrOf a phone that has created a Lastys ID")
        }
        let minutesAgo = Double(arguments["madeMinutesAgo"] ?? "0") ?? 0
        let made = lock.withLock { now }.addingTimeInterval(-minutesAgo * 60)
        let signer = key(of: arguments["signedBy"] ?? shower)
        return try LastysQRToken(personalID: personalID, at: made, signedBy: signer).text
    }
}

extension ScanResult {
    /// The response fields shared with the real Trustee API.
    var fields: [String: String] {
        [
            "status": status.rawValue,
            "nickname": nickname,
            "idAgeDays": String(idAgeDays),
            "phoneTransfers": String(phoneTransferCount),
            "history": relationshipHistory.map { String($0.count) } ?? "hidden",
            "requestBlocked": requestBlock?.code ?? "none",
        ]
    }
}

extension TrusteeError {
    /// The error code shared with the real Trustee API.
    var code: String {
        switch self {
        case .noLastysID: return "no-lastys-id"
        case .phoneAlreadyHasLastysID: return "phone-already-has-lastys-id"
        case .notALastysQR: return "not-a-lastys-qr"
        case .expiredQR: return "expired-qr"
        case .forgedQR: return "forged-qr"
        case .scanRequired: return "scan-required"
        case .scanTooOld: return "scan-too-old"
        case .youAreTaken: return "you-are-taken"
        case .youAreCoolingOff: return "you-are-cooling-off"
        case .theyAreTaken: return "they-are-taken"
        case .theyAreCoolingOff: return "they-are-cooling-off"
        case .thatIsYou: return "that-is-you"
        case .requestNotFound: return "request-not-found"
        case .requestNotPending: return "request-not-pending"
        case .noRelationship: return "no-relationship"
        case .notAllowedNow: return "not-allowed-now"
        case .cannotEscalateYet: return "cannot-escalate-yet"
        }
    }
}

extension RelationshipStatus {
    var fields: [String: String] {
        switch self {
        case .none:
            return ["status": "none"]
        case .coolingOff(let until):
            return ["status": "cooling-off", "until": Self.day(until)]
        case .active(let partnerNickname, _, let stage):
            var fields = ["status": "active", "partner": partnerNickname]
            switch stage {
            case .together:
                fields["stage"] = "together"
            case .ending(let request):
                fields["stage"] = "ending"
                fields["endRequestFrom"] = request.sentByMe ? "me" : "partner"
                fields["declined"] = String(request.declined)
            case .inTeamReview(let review):
                fields["stage"] = "team-review"
                fields["reviewReason"] = review.reason.rawValue
            }
            return fields
        }
    }

    /// A UTC calendar day, `yyyy-MM-dd`.
    private static func day(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

extension RelationshipRequest {
    var fields: [String: String] {
        ["status": status.rawValue, "to": toNickname]
    }
}

extension RelationshipRequestBlock {
    var code: String {
        switch self {
        case .youAreTaken: return "you-are-taken"
        case .youAreCoolingOff: return "you-are-cooling-off"
        case .theyAreTaken: return "they-are-taken"
        case .thatIsYou: return "that-is-you"
        }
    }
}
