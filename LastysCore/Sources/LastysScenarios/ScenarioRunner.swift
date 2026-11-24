import LastysCore

/// Runs a `Scenario` against the fake Trustee, one `TrusteeClient` per phone.
/// Stops at the first failing step, since later steps depend on earlier ones.
public struct ScenarioRunner {
    private let trustee: FakeTrustee

    public init(trustee: FakeTrustee) {
        self.trustee = trustee
    }

    public func run(_ scenario: Scenario) async -> [ScenarioFailure] {
        for (index, step) in scenario.steps.enumerated() {
            let number = index + 1
            let client = trustee.client(forPhone: step.phone)
            let response: [String: String]
            do {
                guard let result = try await perform(step, on: client) else {
                    return [ScenarioFailure(step: number, message: "unknown action \"\(step.action)\"")]
                }
                response = result
            } catch let error as TrusteeError {
                response = ["error": error.code]
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

    /// The response fields for a step, or nil when the action is unknown.
    private func perform(_ step: Scenario.Step, on client: TrusteeClient) async throws -> [String: String]? {
        switch step.action {
        case "create-lastys-id":
            let created = try await client.createLastysID()
            return ["personalID": created.lastysID.personalID, "recoveryCode": created.recoveryCode]
        case "update-profile":
            try await client.updateProfile(nickname: step.arguments["nickname"] ?? "", photo: nil)
            return [:]
        case "get-relationship-status":
            return ["status": try await client.relationshipStatus().code]
        default:
            return nil
        }
    }
}

extension TrusteeError {
    /// The error code shared with the real Trustee API.
    var code: String {
        switch self {
        case .noLastysID: return "no-lastys-id"
        case .phoneAlreadyHasLastysID: return "phone-already-has-lastys-id"
        }
    }
}

extension RelationshipStatus {
    var code: String {
        switch self {
        case .none: return "none"
        }
    }
}
