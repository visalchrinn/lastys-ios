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
        await me.model.scan(try #require(dara.model.myLastysQR()).payload)
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

    // MARK: The card's Lastys QR

    @Test func anotherPhoneScanningTheCardsQRSeesMeAsVerifiedSingle() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        await me.model.prepareVerifiedSingleCard()

        let qr = try #require(me.model.verifiedSingleCardQR())
        await dara.model.scan(qr.payload)

        let result = try #require(dara.model.scanResult)
        #expect(result.nickname == "Srey Pich")
        #expect(result.status == .single)
        #expect(result.relationshipHistory == nil)
    }

    @Test func aScanOfTheCardsQRFollowsMyShareLevelAndShowsInWhoScannedMe() async throws {
        let me = TestPhone()
        await me.onboard()
        await me.model.setShareLevel(.statusAndHistory)
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        await me.model.prepareVerifiedSingleCard()

        await dara.model.scan(try #require(me.model.verifiedSingleCardQR()).payload)
        await me.model.refreshMe()

        #expect(dara.model.scanResult?.relationshipHistory == [])
        #expect(me.model.whoScannedMe == [me.clock.now])
    }

    @Test func thereIsNoQRUntilTheCardHasBeenChecked() async {
        let me = TestPhone()
        await me.onboard()

        #expect(me.model.verifiedSingleCardQR() == nil)
    }

    @Test func aCardMadeWhileTakenHasNoQR() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        try await me.becomePartners(with: dara)

        await me.model.prepareVerifiedSingleCard()

        #expect(me.model.verifiedSingleCardQR() == nil)
    }

    @Test func aSharedCardsQRKeepsWorkingUntilIRevokeMyLastysQR() async throws {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        await me.model.prepareVerifiedSingleCard()
        let qr = try #require(me.model.verifiedSingleCardQR())

        me.clock.advance(days: 30)
        await dara.model.scan(qr.payload)
        #expect(dara.model.scanResult?.nickname == "Srey Pich")

        await me.model.revokeMyLastysQR()
        await dara.model.scan(qr.payload)

        #expect(dara.model.scanResult == nil)
        #expect(dara.model.scanProblem == .revokedQR)
        #expect(me.model.verifiedSingleCardQR()?.payload != qr.payload)
    }
}
