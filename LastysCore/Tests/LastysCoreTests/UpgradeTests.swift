import Foundation
import Testing
import LastysCore

@MainActor
struct UpgradeTests {
    @Test func aPhoneOnboardedByAnEarlierBuildStillGoesStraightToHome() throws {
        let phone = TestPhone()
        // Saved by the build from ticket #3, before the Share level existed.
        try Data(#"""
        {"language":"km","lastysID":{"personalID":"LT-8K2F-91QA"},"recoveryCode":"7QX2-M4KD-9PLA-3HTV",
         "hasSavedRecoveryCode":true,"nickname":"Srey Pich","birthDate":-126748800,"hasFinishedOnboarding":true}
        """#.utf8).write(to: phone.phoneFile)

        phone.relaunch()

        #expect(phone.model.screen == .home)
        #expect(phone.model.lastysID == LastysID(personalID: "LT-8K2F-91QA"))
        #expect(phone.model.nickname == "Srey Pich")
        #expect(phone.model.shareLevel == .statusOnly)
    }

    @Test func trusteeSavedByAnEarlierBuildKeepsTheLastysIDAndNickname() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("trustee-\(UUID().uuidString).json")
        let key = SoftwarePhoneKey()
        // Saved by the build from ticket #3: no per-person records yet.
        try Data("""
        {"lastysIDByPhone":{"\(key.trusteeID)":{"personalID":"LT-8K2F-91QA"}},
         "profileByLastysID":{"LT-8K2F-91QA":{"nickname":"Srey Pich"}}}
        """.utf8).write(to: file)

        let trustee = FakeTrustee(savingTo: file)
        let scanner = trustee.client(forPhone: "scanner")
        _ = try await scanner.createLastysID()
        let qr = try LastysQRToken(personalID: "LT-8K2F-91QA", at: Date(), signedBy: key)

        let result = try await scanner.scan(qr.text)

        #expect(result.nickname == "Srey Pich")
        await #expect(throws: TrusteeError.phoneAlreadyHasLastysID) {
            try await trustee.client(forPhone: key.trusteeID).createLastysID()
        }
    }

    @Test func anUpgradedLastysIDKeepsAgingFromTheFirstLaunchAfterTheUpdate() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("trustee-\(UUID().uuidString).json")
        let key = SoftwarePhoneKey()
        try Data("""
        {"lastysIDByPhone":{"\(key.trusteeID)":{"personalID":"LT-8K2F-91QA"}}}
        """.utf8).write(to: file)
        let updated = Date(timeIntervalSince1970: 1_795_928_415)
        _ = FakeTrustee(savingTo: file, now: { updated })

        let tenDaysLater = updated.addingTimeInterval(10 * 86_400)
        let trustee = FakeTrustee(savingTo: file, now: { tenDaysLater })
        let scanner = trustee.client(forPhone: "scanner")
        _ = try await scanner.createLastysID()
        let result = try await scanner.scan(LastysQRToken(personalID: "LT-8K2F-91QA", at: tenDaysLater, signedBy: key).text)

        #expect(result.idAgeDays == 10)
    }

    @Test func trusteeSavedByTheScanBuildStillLoadsItsPeople() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("trustee-\(UUID().uuidString).json")
        let key = SoftwarePhoneKey()
        // Saved by the build from ticket #5: people have no Relationship fields yet.
        try Data("""
        {"lastysIDByPhone":{"\(key.trusteeID)":{"personalID":"LT-8K2F-91QA"}},
         "people":{"LT-8K2F-91QA":{"lastysID":{"personalID":"LT-8K2F-91QA"},"createdAt":0,"nickname":"Srey Pich",
                   "shareLevel":"status-only","pastRelationships":[],"phoneTransferCount":0}}}
        """.utf8).write(to: file)

        let trustee = FakeTrustee(savingTo: file)

        #expect(try await trustee.client(forPhone: key.trusteeID).relationshipStatus() == .none)
        let scanner = trustee.client(forPhone: "scanner")
        _ = try await scanner.createLastysID()
        let result = try await scanner.scan(LastysQRToken(personalID: "LT-8K2F-91QA", at: Date(), signedBy: key).text)
        #expect(result.nickname == "Srey Pich")
    }

    @Test func aCachedRelationshipThisBuildCannotReadNeverCostsTheLastysID() throws {
        let phone = TestPhone()
        try Data(#"""
        {"lastysID":{"personalID":"LT-8K2F-91QA"},"recoveryCode":"7QX2-M4KD-9PLA-3HTV","hasSavedRecoveryCode":true,
         "nickname":"Srey Pich","hasFinishedOnboarding":true,"relationship":{"somethingNewer":{"x":1}}}
        """#.utf8).write(to: phone.phoneFile)

        phone.relaunch()

        #expect(phone.model.screen == .home)
        #expect(phone.model.lastysID == LastysID(personalID: "LT-8K2F-91QA"))
        #expect(phone.model.relationship == .none)
    }
}
