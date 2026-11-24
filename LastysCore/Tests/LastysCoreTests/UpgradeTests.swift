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
}
