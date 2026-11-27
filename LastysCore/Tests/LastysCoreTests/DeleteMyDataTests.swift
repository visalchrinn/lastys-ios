import Foundation
import Testing
import LastysCore

@MainActor
struct DeleteMyDataTests {
    @Test func deletingWhenNotInARelationshipWipesEverythingAndShowsOnboarding() async throws {
        let me = TestPhone()
        await me.onboard()
        me.model.addMoment(MomentDraft(type: .birthday, title: "Mom's birthday", date: Date().addingTimeInterval(5 * 86_400), repeatsOnKhmerLunarDate: false))
        me.model.plannerPartnerBirthDate = Date(timeIntervalSince1970: 800_000_000)
        #expect(me.model.canDeleteMyData)

        await me.model.deleteMyData()

        #expect(me.model.screen == .onboarding(.intro(page: 0)))
        #expect(me.model.lastysID == nil)
        #expect(me.model.moments.isEmpty)
        #expect(me.model.birthDate == nil)
        #expect(me.model.plannerPartnerBirthDate == nil)
        #expect(me.reminders.scheduled.isEmpty)
        await #expect(throws: TrusteeError.noLastysID) {
            try await me.trustee.client(forPhone: me.key.trusteeID).relationshipStatus()
        }
        me.relaunch()
        #expect(me.model.screen == .onboarding(.intro(page: 0)))
    }

    @Test(arguments: [false, true])
    func deletingWhileTakenIsRefusedWithAReason(ending: Bool) async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        try await me.becomePartners(with: dara)
        if ending { await me.model.perform(.sendEndRequest) }
        #expect(!me.model.canDeleteMyData)

        await me.model.deleteMyData()

        #expect(me.model.deleteProblem == .relationshipNotOver)
        #expect(me.model.screen == .home)
        #expect(me.model.lastysID != nil)
        _ = try await me.trustee.client(forPhone: me.key.trusteeID).relationshipStatus()
    }

    @Test func deletingNeedsFaceIDOrThePasscode() async {
        let me = TestPhone()
        await me.onboard()
        me.authenticator.allows = false

        await me.model.deleteMyData()

        #expect(me.model.deleteProblem == .notAuthenticated)
        #expect(me.model.lastysID != nil)
    }

    @Test func deletingWithoutInternetKeepsTheLastysID() async {
        let me = TestPhone()
        await me.onboard()
        me.isOnline = false

        await me.model.deleteMyData()

        #expect(me.model.deleteProblem == .needsInternet)
        #expect(me.model.screen == .home)
        #expect(me.model.lastysID != nil)
    }

    @Test func afterDeletingThisPhoneCannotMakeANewLastysIDStraightAway() async {
        let me = TestPhone()
        await me.onboard()
        await me.model.deleteMyData()

        await me.createLastysID()

        #expect(me.model.screen == .onboarding(.welcome))
        #expect(me.model.onboardingProblem == .phoneMadeALastysIDRecently)
        #expect(me.model.lastysID == nil)
    }
}
