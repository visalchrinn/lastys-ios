import Foundation
import Testing
@testable import LastysCore

@MainActor
struct OnboardingTests {
    @Test func aFirstLaunchStartsWithTheIntro() {
        let phone = TestPhone()

        #expect(phone.model.screen == .onboarding(.intro(page: 0)))
    }

    @Test func skippingTheIntroGoesToChoosingALanguage() {
        let phone = TestPhone()

        phone.model.skipIntro()

        #expect(phone.model.screen == .onboarding(.language))
    }

    @Test func readingEveryIntroPageGoesToChoosingALanguage() {
        let phone = TestPhone()

        for _ in 0..<AppModel.introPageCount { phone.model.nextIntroPage() }

        #expect(phone.model.screen == .onboarding(.language))
    }

    @Test func khmerIsTheDefaultLanguage() {
        let phone = TestPhone()

        #expect(phone.model.language == .khmer)
    }

    @Test func theChosenLanguageIsUsedFromThenOn() {
        let phone = TestPhone()
        phone.model.skipIntro()

        phone.model.chooseLanguage(.english)
        phone.model.confirmLanguage()

        #expect(phone.model.language == .english)
        #expect(phone.model.screen == .onboarding(.consent))
    }

    @Test(arguments: [(false, false), (true, false), (false, true)])
    func cannotContinueWithoutConfirming18PlusAndAcceptingTheTerms(isOver18: Bool, acceptsTerms: Bool) async {
        let phone = TestPhone()
        phone.model.skipIntro()
        phone.model.confirmLanguage()

        phone.model.isOver18 = isOver18
        phone.model.acceptsTerms = acceptsTerms
        await phone.model.continueFromConsent()

        #expect(!phone.model.canContinueFromConsent)
        #expect(phone.model.screen == .onboarding(.consent))
        #expect(phone.model.lastysID == nil)
    }

    @Test func confirming18PlusAndTheTermsCreatesALastysIDWithAPersonalIDAndRecoveryCode() async throws {
        let phone = TestPhone()
        phone.model.skipIntro()
        phone.model.confirmLanguage()

        phone.model.isOver18 = true
        phone.model.acceptsTerms = true
        await phone.model.continueFromConsent()

        #expect(phone.model.screen == .onboarding(.recoveryCode))
        let personalID = try #require(phone.model.lastysID?.personalID)
        #expect(personalID.wholeMatch(of: /LT-[0-9A-Z]{4}-[0-9A-Z]{4}/) != nil)
        let recoveryCode = try #require(phone.model.recoveryCode)
        #expect(recoveryCode.wholeMatch(of: /[0-9A-Z]{4}(-[0-9A-Z]{4}){3}/) != nil)
    }
}
