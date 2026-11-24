import Foundation
import Testing
import LastysCore

@MainActor
struct EndingTests {
    /// Dara and me, in a Relationship.
    private func partners() async throws -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        try await me.becomePartners(with: dara)
        return (dara, me)
    }

    @Test func togetherEitherPartnerCanSendAnEndRequestOrReportASafetyConcern() async throws {
        let (dara, me) = try await partners()

        #expect(me.model.endingActions == [.sendEndRequest, .reportSafetyConcern])
        #expect(dara.model.endingActions == [.sendEndRequest, .reportSafetyConcern])
    }

    @Test func afterSendingAnEndRequestIStayTakenWhileTheyHave7DaysToAnswer() async throws {
        let (dara, me) = try await partners()

        await me.model.perform(.sendEndRequest)

        guard case .active(let partner, _, .ending(let request)) = me.model.relationship else {
            Issue.record("expected an ending Relationship, got \(me.model.relationship)")
            return
        }
        #expect(partner == "Dara")
        #expect(request.sentByMe)
        #expect(request.answerBy == me.clock.now.addingTimeInterval(7 * 86_400))
        #expect(me.model.endingActions == [.withdrawEndRequest, .reportSafetyConcern])
        await dara.model.start()
        #expect(dara.model.endingActions == [.agreeToEndRequest, .declineEndRequest, .reportSafetyConcern])
    }

    @Test func whenThePartnerAgreesBothEnterA7DayCoolingOffPeriod() async throws {
        let (dara, me) = try await partners()
        await me.model.perform(.sendEndRequest)
        await dara.model.start()

        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        let until = me.clock.now.addingTimeInterval(7 * 86_400)
        #expect(me.model.relationship == .coolingOff(until: until))
        #expect(dara.model.relationship == .coolingOff(until: until))
        #expect(me.model.endingActions.isEmpty)
    }

    @Test func afterADeclineTheRequesterCanAskForATeamReview() async throws {
        let (dara, me) = try await partners()
        await me.model.perform(.sendEndRequest)
        await dara.model.start()

        await dara.model.perform(.declineEndRequest)
        await me.model.start()

        #expect(me.model.endingActions == [.withdrawEndRequest, .escalateToTeamReview, .reportSafetyConcern])
        #expect(dara.model.endingActions == [.reportSafetyConcern])
    }

    @Test func aTeamReviewOpensAfter7DaysWithNoAnswer() async throws {
        let (_, me) = try await partners()
        await me.model.perform(.sendEndRequest)

        me.clock.advance(days: 6.9)
        #expect(!me.model.endingActions.contains(.escalateToTeamReview))
        me.clock.advance(days: 0.1)
        #expect(me.model.endingActions.contains(.escalateToTeamReview))

        await me.model.perform(.escalateToTeamReview)

        guard case .active(_, _, .inTeamReview(let review)) = me.model.relationship else {
            Issue.record("expected a Team review, got \(me.model.relationship)")
            return
        }
        #expect(review.reason == .endRequest)
        #expect(me.model.endingActions == [.reportSafetyConcern])
    }

    @Test func aSafetyConcernGoesStraightToTeamReview() async throws {
        let (dara, me) = try await partners()

        await me.model.perform(.reportSafetyConcern)
        await dara.model.start()

        guard case .active(_, _, .inTeamReview(let review)) = dara.model.relationship else {
            Issue.record("expected a Team review, got \(dara.model.relationship)")
            return
        }
        #expect(review.reason == .safetyConcern)
        #expect(dara.model.endingActions.isEmpty)
    }

    @Test func anActionThatIsNotOpenNeverReachesTrustee() async throws {
        let (_, me) = try await partners()
        await me.model.perform(.sendEndRequest)
        let requestsBefore = me.trusteeRequests

        await me.model.perform(.agreeToEndRequest)

        #expect(me.trusteeRequests == requestsBefore)
        guard case .active = me.model.relationship else {
            Issue.record("a Relationship never ends one-sidedly, got \(me.model.relationship)")
            return
        }
    }

    @Test func theCoolingOffPeriodIsOverAfter7DaysEvenBeforeTrusteeIsAsked() async throws {
        let (dara, me) = try await partners()
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        me.clock.advance(days: 7)

        #expect(me.model.relationship == .none)
    }
}
