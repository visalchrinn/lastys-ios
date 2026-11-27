import Foundation
import Testing
@testable import LastysCore

@MainActor
struct OnboardingTests {
    @Test func aFirstLaunchStartsWithTheIntro() {
        let phone = TestPhone()

        #expect(phone.model.screen == .onboarding(.intro(page: 0)))
    }

    @Test func skippingTheIntroGoesToWelcome() {
        let phone = TestPhone()

        phone.model.skipIntro()

        #expect(phone.model.screen == .onboarding(.welcome))
    }

    @Test func readingEveryIntroPageGoesToWelcome() {
        let phone = TestPhone()

        for _ in 0..<AppModel.introPageCount { phone.model.nextIntroPage() }

        #expect(phone.model.screen == .onboarding(.welcome))
    }

    @Test func khmerIsTheDefaultLanguage() {
        let phone = TestPhone()

        #expect(phone.model.language == .khmer)
    }

    @Test func switchingLanguageOnWelcomeAppliesAtOnceAndStaysOnWelcome() {
        let phone = TestPhone()
        phone.model.skipIntro()

        phone.model.chooseLanguage(.english)

        #expect(phone.model.language == .english)
        #expect(phone.model.screen == .onboarding(.welcome))
    }

    @Test func theLanguageChosenOnWelcomeIsKeptAfterTheLastysIDIsCreated() async {
        let phone = TestPhone()
        phone.model.skipIntro()
        phone.model.chooseLanguage(.english)

        phone.model.acceptsTerms = true
        await phone.model.getStarted()
        phone.relaunch()

        #expect(phone.model.language == .english)
    }

    @Test func cannotGetStartedWithoutTickingTheConsentLine() async {
        let phone = TestPhone()
        phone.model.skipIntro()

        await phone.model.getStarted()

        #expect(!phone.model.canGetStarted)
        #expect(phone.model.screen == .onboarding(.welcome))
        #expect(phone.model.lastysID == nil)
    }

    @Test func tickingTheConsentLineAndGettingStartedCreatesALastysIDWithAPersonalIDAndRecoveryCode() async throws {
        let phone = TestPhone()
        phone.model.skipIntro()

        phone.model.acceptsTerms = true
        #expect(phone.model.canGetStarted)
        await phone.model.getStarted()

        #expect(phone.model.screen == .onboarding(.recoveryCode))
        let personalID = try #require(phone.model.lastysID?.personalID)
        #expect(personalID.wholeMatch(of: /LT-[0-9A-Z]{4}-[0-9A-Z]{4}/) != nil)
        let recoveryCode = try #require(phone.model.recoveryCode)
        #expect(recoveryCode.wholeMatch(of: /[0-9A-Z]{4}(-[0-9A-Z]{4}){3}/) != nil)
    }
}
