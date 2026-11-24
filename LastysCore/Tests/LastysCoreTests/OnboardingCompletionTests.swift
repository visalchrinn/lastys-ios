import Foundation
import Testing
@testable import LastysCore

@MainActor
struct OnboardingCompletionTests {
    private func fillInProfile(on phone: TestPhone, nickname: String = "Srey Pich") {
        phone.model.profileNickname = nickname
        phone.model.profileBirthDate = TestPhone.birthDate
    }

    @Test func cannotContinueWithoutConfirmingTheRecoveryCodeIsSaved() async {
        let phone = TestPhone()
        await phone.createLastysID()

        phone.model.continueFromRecoveryCode()

        #expect(!phone.model.canContinueFromRecoveryCode)
        #expect(phone.model.screen == .onboarding(.recoveryCode))
    }

    @Test func confirmingTheRecoveryCodeIsSavedGoesToTheProfile() async {
        let phone = TestPhone()
        await phone.createLastysID()

        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()

        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test(arguments: ["", "   "])
    func cannotFinishTheProfileWithoutANickname(nickname: String) async {
        let phone = TestPhone()
        await phone.createLastysID()
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()
        fillInProfile(on: phone, nickname: nickname)

        await phone.model.finishProfile()

        #expect(!phone.model.canFinishProfile)
        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func cannotFinishTheProfileWithoutABirthDate() async {
        let phone = TestPhone()
        await phone.createLastysID()
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()
        phone.model.profileNickname = "Srey Pich"

        await phone.model.finishProfile()

        #expect(!phone.model.canFinishProfile)
        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func finishingOnboardingLandsOnHomeAsVerifiedSingleWithTheNickname() async {
        let phone = TestPhone()

        await phone.onboard()

        #expect(phone.model.screen == .home)
        #expect(phone.model.nickname == "Srey Pich")
        #expect(phone.model.relationship == .none)
        #expect(phone.model.birthDate == TestPhone.birthDate)
    }

    @Test func theBirthDateNeverGoesThroughTrustee() async {
        let phone = TestPhone()

        await phone.onboard()
        await phone.model.start()

        #expect(phone.model.screen == .home)
        #expect(phone.trusteeRequests.contains("updateProfile(nickname: Srey Pich, photo: nil)"))
        let birthDateForms = ["\(TestPhone.birthDate)", "1996", "851558400"]
        for request in phone.trusteeRequests {
            #expect(!birthDateForms.contains { request.contains($0) }, "\(request)")
        }
    }

    @Test func aRelaunchAfterOnboardingGoesStraightToHome() async {
        let phone = TestPhone()
        await phone.onboard()
        let lastysID = phone.model.lastysID

        phone.relaunch()
        await phone.model.start()

        #expect(phone.model.screen == .home)
        #expect(phone.model.lastysID == lastysID)
        #expect(phone.model.nickname == "Srey Pich")
        #expect(phone.model.relationship == .none)
    }

    @Test func aRelaunchBeforeSavingTheRecoveryCodeShowsTheSameRecoveryCodeAgain() async {
        let phone = TestPhone()
        await phone.createLastysID()
        let lastysID = phone.model.lastysID
        let recoveryCode = phone.model.recoveryCode

        phone.relaunch()

        #expect(phone.model.screen == .onboarding(.recoveryCode))
        #expect(phone.model.lastysID == lastysID)
        #expect(phone.model.recoveryCode == recoveryCode)
    }

    @Test func aRelaunchBeforeFinishingTheProfileReturnsToTheProfile() async {
        let phone = TestPhone()
        await phone.createLastysID()
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()

        phone.relaunch()

        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func whenTrusteeRefusesASecondLastysIDForThisPhoneOnboardingSaysSo() async throws {
        let phone = TestPhone()
        try await phone.trusteeAlreadyHoldsALastysIDForThisPhone()

        await phone.createLastysID()

        #expect(phone.model.screen == .onboarding(.consent))
        #expect(phone.model.onboardingProblem == .phoneAlreadyHasLastysID)
        #expect(phone.model.lastysID == nil)
    }
}
