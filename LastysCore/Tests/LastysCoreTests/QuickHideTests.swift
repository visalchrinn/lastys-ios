import Foundation
import Testing
import LastysCore

@MainActor
struct QuickHideTests {
    /// Dara and me, in a Relationship, with one personal and one Shared Moment coming up.
    private func partners() async throws -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara, moments: [
            Moment(type: .birthday, title: "Mom's birthday", date: Date().addingTimeInterval(5 * 86_400)),
            Moment(type: .anniversary, title: "Our first date", date: Date().addingTimeInterval(9 * 86_400), isShared: true),
        ])
        await me.onboard()
        try await me.becomePartners(with: dara)
        return (dara, me)
    }

    @Test func quickHideIsOfferedToEveryoneSoItsPresenceRevealsNothing() async throws {
        let single = TestPhone()
        await single.onboard()
        #expect(single.model.canUseQuickHide)

        let (_, me) = try await partners()
        #expect(me.model.canUseQuickHide)
    }

    @Test func quickHideHidesTheStatusCardAndSharedMomentsButNotPersonalOnes() async throws {
        let (_, me) = try await partners()
        #expect(me.model.showsStatusCard)
        #expect(me.model.upcomingMoments.map(\.moment.title) == ["Mom's birthday", "Our first date"])

        me.model.setQuickHide(true)

        #expect(!me.model.showsStatusCard)
        #expect(me.model.upcomingMoments.map(\.moment.title) == ["Mom's birthday"])
        #expect(me.model.timeline.map(\.title) == ["Mom's birthday"])
    }

    @Test func quickHideStaysOnAfterARelaunchAndNeverReachesTrustee() async throws {
        let (_, me) = try await partners()
        let requestsBefore = me.trusteeRequests

        me.model.setQuickHide(true)
        #expect(me.trusteeRequests == requestsBefore)
        me.relaunch()

        #expect(me.model.isQuickHideOn)
        #expect(!me.model.showsStatusCard)
    }

    @Test func aScanOfSomeoneUsingQuickHideStillShowsTaken() async throws {
        let (dara, me) = try await partners()
        me.model.setQuickHide(true)
        let vanna = TestPhone(nearby: dara)
        await vanna.onboard(as: "Vanna")

        await vanna.model.scan(try #require(me.model.myLastysQR(at: Date())).payload)

        #expect(vanna.model.scanResult?.status == .taken)
    }

    @Test func quickHideCanBeTurnedOffAfterTheRelationshipEnds() async throws {
        let (dara, me) = try await partners()
        me.model.setQuickHide(true)
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        me.model.setQuickHide(false)

        #expect(me.model.showsStatusCard)
    }
}
