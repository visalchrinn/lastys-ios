import Foundation
import Testing
@testable import LastysCore

@MainActor
struct OnboardingCompletionTests {
    private static let birthDate = Date(timeIntervalSince1970: 851_558_400) // 26 Dec 1996

    /// Takes a fresh phone through the intro, language and consent to the Recovery code.
    private func createLastysID(on phone: TestPhone) async {
        phone.model.skipIntro()
        phone.model.confirmLanguage()
        phone.model.isOver18 = true
        phone.model.acceptsTerms = true
        await phone.model.continueFromConsent()
    }

    private func fillInProfile(on phone: TestPhone, nickname: String = "Srey Pich") {
        phone.model.profileNickname = nickname
        phone.model.profileBirthDate = Self.birthDate
    }

    private func onboard(_ phone: TestPhone) async {
        await createLastysID(on: phone)
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()
        fillInProfile(on: phone)
        await phone.model.finishProfile()
    }

    @Test func cannotContinueWithoutConfirmingTheRecoveryCodeIsSaved() async {
        let phone = TestPhone()
        await createLastysID(on: phone)

        phone.model.continueFromRecoveryCode()

        #expect(!phone.model.canContinueFromRecoveryCode)
        #expect(phone.model.screen == .onboarding(.recoveryCode))
    }

    @Test func confirmingTheRecoveryCodeIsSavedGoesToTheProfile() async {
        let phone = TestPhone()
        await createLastysID(on: phone)

        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()

        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test(arguments: ["", "   "])
    func cannotFinishTheProfileWithoutANickname(nickname: String) async {
        let phone = TestPhone()
        await createLastysID(on: phone)
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()
        fillInProfile(on: phone, nickname: nickname)

        await phone.model.finishProfile()

        #expect(!phone.model.canFinishProfile)
        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func cannotFinishTheProfileWithoutABirthDate() async {
        let phone = TestPhone()
        await createLastysID(on: phone)
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()
        phone.model.profileNickname = "Srey Pich"

        await phone.model.finishProfile()

        #expect(!phone.model.canFinishProfile)
        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func finishingOnboardingLandsOnHomeAsVerifiedSingleWithTheNickname() async {
        let phone = TestPhone()

        await onboard(phone)

        #expect(phone.model.screen == .home)
        #expect(phone.model.nickname == "Srey Pich")
        #expect(phone.model.relationship == .none)
        #expect(phone.model.birthDate == Self.birthDate)
    }

    @Test func theBirthDateNeverGoesThroughTrustee() async {
        let recorder = RecordingTrustee(FakeTrustee().client(forPhone: "phone-a"))
        let model = AppModel(trustee: recorder, store: InMemoryPhoneStore())
        model.skipIntro()
        model.confirmLanguage()
        model.isOver18 = true
        model.acceptsTerms = true
        await model.continueFromConsent()
        model.hasSavedRecoveryCode = true
        model.continueFromRecoveryCode()
        model.profileNickname = "Srey Pich"
        model.profileBirthDate = Self.birthDate
        await model.finishProfile()
        await model.start()

        #expect(model.screen == .home)
        #expect(recorder.requests.contains("updateProfile(nickname: Srey Pich, photo: nil)"))
        let birthDateForms = ["\(Self.birthDate)", "1996", "851558400"]
        for request in recorder.requests {
            #expect(!birthDateForms.contains { request.contains($0) }, "\(request)")
        }
    }

    @Test func aRelaunchAfterOnboardingGoesStraightToHome() async {
        let phone = TestPhone()
        await onboard(phone)
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
        await createLastysID(on: phone)
        let lastysID = phone.model.lastysID
        let recoveryCode = phone.model.recoveryCode

        phone.relaunch()

        #expect(phone.model.screen == .onboarding(.recoveryCode))
        #expect(phone.model.lastysID == lastysID)
        #expect(phone.model.recoveryCode == recoveryCode)
    }

    @Test func aRelaunchBeforeFinishingTheProfileReturnsToTheProfile() async {
        let phone = TestPhone()
        await createLastysID(on: phone)
        phone.model.hasSavedRecoveryCode = true
        phone.model.continueFromRecoveryCode()

        phone.relaunch()

        #expect(phone.model.screen == .onboarding(.profile))
    }

    @Test func whenTrusteeRefusesASecondLastysIDForThisPhoneOnboardingSaysSo() async throws {
        let phone = TestPhone()
        try await phone.trusteeAlreadyHoldsALastysIDForThisPhone()

        await createLastysID(on: phone)

        #expect(phone.model.screen == .onboarding(.consent))
        #expect(phone.model.onboardingProblem == .phoneAlreadyHasLastysID)
        #expect(phone.model.lastysID == nil)
    }
}
