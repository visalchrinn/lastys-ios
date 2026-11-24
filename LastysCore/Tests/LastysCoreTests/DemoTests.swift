#if DEBUG
import Foundation
import Testing
import LastysCore

@MainActor
struct DemoTests {
    private func me() async -> TestPhone {
        let me = TestPhone()
        await me.onboard()
        return me
    }

    @Test func demoDaraIsSingleAndSharesHerRelationshipHistoryAsMonthsOnly() async throws {
        let me = await me()

        await me.model.scan(try await me.trustee.demoLastysQR(of: .dara, at: Date()))

        let result = try #require(me.model.scanResult)
        #expect(result.nickname == "Dara")
        #expect(result.status == .single)
        #expect(!result.isVeryNew)
        #expect(result.phoneTransferCount == 1)
        #expect(result.relationshipHistory == [
            PastRelationship(started: YearMonth(year: 2022, month: 3), ended: YearMonth(year: 2023, month: 1)),
            PastRelationship(started: YearMonth(year: 2023, month: 6), ended: YearMonth(year: 2024, month: 2)),
        ])
    }

    @Test func demoVannaHasABrandNewLastysIDAndSharesStatusOnly() async throws {
        let me = await me()

        await me.model.scan(try await me.trustee.demoLastysQR(of: .vanna, at: Date()))

        let result = try #require(me.model.scanResult)
        #expect(result.nickname == "Vanna")
        #expect(result.isVeryNew)
        #expect(result.relationshipHistory == nil)
    }

    @Test func demoSokhaIsTaken() async throws {
        let me = await me()

        await me.model.scan(try await me.trustee.demoLastysQR(of: .sokha, at: Date()))

        #expect(me.model.scanResult?.status == .taken)
    }

    @Test func demoPeopleAreTheSamePeopleEveryTime() async throws {
        let me = await me()

        let first = try await me.trustee.demoLastysQR(of: .dara, at: Date())
        let second = try await me.trustee.demoLastysQR(of: .dara, at: Date())

        #expect(LastysQRToken(parsing: first)?.personalID == LastysQRToken(parsing: second)?.personalID)
    }

    @Test func demoSokhaCannotReceiveARelationshipRequest() async throws {
        let me = await me()

        await me.model.scan(try await me.trustee.demoLastysQR(of: .sokha, at: Date()))

        #expect(me.model.scanResult?.requestBlock == .theyAreTaken)
    }

    @Test func demoDaraAcceptsMyRelationshipRequest() async throws {
        let me = await me()
        await me.model.scan(try await me.trustee.demoLastysQR(of: .dara, at: Date()))
        await me.model.sendRelationshipRequest()

        try await me.trustee.demoRespondToRelationshipRequest(id: try #require(me.model.outgoingRequest?.id), accept: true)
        await me.model.refreshOutgoingRequest()

        #expect(me.model.outgoingRequest?.status == .accepted)
        #expect(me.model.relationship != .none)
    }

    @Test func demoVannaDeclinesMyRelationshipRequest() async throws {
        let me = await me()
        await me.model.scan(try await me.trustee.demoLastysQR(of: .vanna, at: Date()))
        await me.model.sendRelationshipRequest()

        try await me.trustee.demoRespondToRelationshipRequest(id: try #require(me.model.outgoingRequest?.id), accept: false)
        await me.model.refreshOutgoingRequest()

        #expect(me.model.outgoingRequest?.status == .declined)
        #expect(me.model.relationship == .none)
    }

    /// Me, in a Relationship with demo Dara.
    private func meWithDara() async throws -> TestPhone {
        let me = await me()
        await me.model.scan(try await me.trustee.demoLastysQR(of: .dara, at: Date()))
        await me.model.sendRelationshipRequest()
        try await me.trustee.demoRespondToRelationshipRequest(id: try #require(me.model.outgoingRequest?.id), accept: true)
        await me.model.refreshOutgoingRequest()
        return me
    }

    @Test func demoPartnerAgreesToMyEndRequestAndICanSkipTheCoolingOffPeriod() async throws {
        let me = try await meWithDara()
        let myID = try #require(me.model.lastysID?.personalID)
        await me.model.perform(.sendEndRequest)

        try await me.trustee.demoPartnerRespondsToEndRequest(of: myID, agree: true)
        await me.model.start()
        guard case .coolingOff = me.model.relationship else {
            Issue.record("expected the Cooling-off period, got \(me.model.relationship)")
            return
        }

        try await me.trustee.demoSkipCoolingOff(of: myID)
        await me.model.start()
        #expect(me.model.relationship == .none)
    }

    @Test func demoNoAnswerAfter7DaysLetsMeAskForATeamReviewAndTheTeamEndsIt() async throws {
        let me = try await meWithDara()
        let myID = try #require(me.model.lastysID?.personalID)
        await me.model.perform(.sendEndRequest)

        try await me.trustee.demoNoAnswerFor7Days(toEndRequestOf: myID)
        await me.model.start()
        #expect(me.model.endingActions.contains(.escalateToTeamReview))

        await me.model.perform(.escalateToTeamReview)
        try await me.trustee.teamDecides(aboutRelationshipOf: myID, endIt: true)
        await me.model.start()
        guard case .coolingOff = me.model.relationship else {
            Issue.record("expected the Cooling-off period, got \(me.model.relationship)")
            return
        }
    }

    @Test func demoPartnerSendsAnEndRequestSoICanAgreeOrDecline() async throws {
        let me = try await meWithDara()

        try await me.trustee.demoPartnerSendsEndRequest(of: try #require(me.model.lastysID?.personalID))
        await me.model.start()

        #expect(me.model.endingActions == [.agreeToEndRequest, .declineEndRequest, .reportSafetyConcern])
    }

    @Test func demoPartnerReportsASafetyConcern() async throws {
        let me = try await meWithDara()

        try await me.trustee.demoPartnerReportsSafetyConcern(of: try #require(me.model.lastysID?.personalID))
        await me.model.start()

        guard case .active(_, _, .inTeamReview(let review)) = me.model.relationship else {
            Issue.record("expected a Team review, got \(me.model.relationship)")
            return
        }
        #expect(review.reason == .safetyConcern)
    }
}
#endif
