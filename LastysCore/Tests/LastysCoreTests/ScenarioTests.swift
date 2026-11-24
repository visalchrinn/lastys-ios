import Foundation
import Testing
import LastysCore
import LastysScenarios

/// The shared scenarios in /scenarios, run against the fake Trustee.
/// The same files run against the real Trustee API from .NET.
struct ScenarioTests {
    static let scenarioDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // LastysCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // LastysCore
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("scenarios")

    static let sharedScenarios: [Scenario] = {
        let files = (try? FileManager.default.contentsOfDirectory(at: scenarioDirectory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try! Scenario.load(from: $0) }
    }()

    @Test func theSharedScenarioFolderIsNotEmpty() {
        #expect(!Self.sharedScenarios.isEmpty)
    }

    @Test(arguments: sharedScenarios)
    func sharedScenarioPassesAgainstTheFakeTrustee(_ scenario: Scenario) async {
        let failures = await ScenarioRunner(trustee: FakeTrustee()).run(scenario)
        #expect(failures.isEmpty, "\(failures)")
    }

    @Test func aWrongExpectationIsReportedWithItsStep() async throws {
        let scenario = try Scenario.decode(#"""
        {
          "name": "Expects the wrong status",
          "steps": [
            { "phone": "alice", "do": "create-lastys-id", "with": { "nickname": "Alice" } },
            { "phone": "alice", "do": "get-relationship-status", "expect": { "status": "active" } }
          ]
        }
        """#)

        let failures = await ScenarioRunner(trustee: FakeTrustee()).run(scenario)

        #expect(failures == [
            ScenarioFailure(step: 2, message: #"expected status = "active", got "none""#),
        ])
    }

    @Test func aTrusteeErrorIsAResultAScenarioCanExpect() async throws {
        let scenario = try Scenario.decode(#"""
        {
          "name": "A phone without a Lastys ID has no status",
          "steps": [
            { "phone": "alice", "do": "get-relationship-status", "expect": { "error": "no-lastys-id" } }
          ]
        }
        """#)

        let failures = await ScenarioRunner(trustee: FakeTrustee()).run(scenario)

        #expect(failures.isEmpty, "\(failures)")
    }

    @Test func anUnknownActionFailsTheScenario() async throws {
        let scenario = try Scenario.decode(#"""
        { "name": "Typo", "steps": [ { "phone": "alice", "do": "crate-lastys-id" } ] }
        """#)

        let failures = await ScenarioRunner(trustee: FakeTrustee()).run(scenario)

        #expect(failures == [ScenarioFailure(step: 1, message: #"unknown action "crate-lastys-id""#)])
    }
}
