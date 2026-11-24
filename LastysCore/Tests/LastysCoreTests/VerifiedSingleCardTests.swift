import Foundation
import Testing
import LastysCore

@MainActor
struct VerifiedSingleCardTests {
    @Test func theCardCarriesMyNicknameAndTodaysCheckedDate() async throws {
        let me = TestPhone()
        await me.onboard()
        #expect(me.model.canShareVerifiedSingleCard)

        await me.model.prepareVerifiedSingleCard()

        let card = try #require(me.model.verifiedSingleCard)
        #expect(card.nickname == "Srey Pich")
        #expect(card.checkedAt == me.clock.now)
    }

    @Test func theCardIsUnavailableWhileTaken() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        try await me.becomePartners(with: dara)

        #expect(!me.model.canShareVerifiedSingleCard)
        await me.model.prepareVerifiedSingleCard()

        #expect(me.model.verifiedSingleCard == nil)
        #expect(me.model.verifiedSingleCardProblem == .hasActiveRelationship)
    }

    @Test func theCardIsCheckedWithTrusteeSoItNeverVouchesForAStaleStatus() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        // Dara accepts my request on her phone; my phone hasn't heard yet.
        await me.model.scan(try #require(dara.model.myLastysQR(at: me.clock.now)).payload)
        await me.model.sendRelationshipRequest()
        try await dara.trustee.client(forPhone: dara.key.trusteeID)
            .respondToRelationshipRequest(id: try #require(me.model.outgoingRequest?.id), accept: true)
        #expect(me.model.relationship == .none)

        await me.model.prepareVerifiedSingleCard()

        #expect(me.model.verifiedSingleCard == nil)
        #expect(me.model.verifiedSingleCardProblem == .hasActiveRelationship)
    }

    @Test func theCardIsAvailableInTheCoolingOffPeriod() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        try await me.becomePartners(with: dara)
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()
        guard case .coolingOff = me.model.relationship else {
            Issue.record("expected the Cooling-off period")
            return
        }

        #expect(me.model.canShareVerifiedSingleCard)
        await me.model.prepareVerifiedSingleCard()

        #expect(me.model.verifiedSingleCard != nil)
    }

    @Test func theCardNeedsInternetToBeChecked() async {
        let me = TestPhone()
        await me.onboard()
        me.isOnline = false

        await me.model.prepareVerifiedSingleCard()

        #expect(me.model.verifiedSingleCard == nil)
        #expect(me.model.verifiedSingleCardProblem == .needsInternet)
    }
}
