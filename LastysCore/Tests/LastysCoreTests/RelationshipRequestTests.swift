import Foundation
import Testing
import LastysCore

@MainActor
struct RelationshipRequestTests {
    /// Dara and me, both onboarded, and me having just Scanned Dara.
    private func meHavingScannedDara() async throws -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        await me.model.scan(try #require(dara.model.myLastysQR(at: Date())).payload)
        return (dara, me)
    }

    private func respond(as receiver: TestPhone, to request: RelationshipRequest, accept: Bool) async throws {
        try await receiver.trustee.client(forPhone: receiver.key.trusteeID)
            .respondToRelationshipRequest(id: request.id, accept: accept)
    }

    @Test func aSingleScannerCanSendASingleScannedPersonARelationshipRequestAndWaitsForThem() async throws {
        let (_, me) = try await meHavingScannedDara()
        #expect(me.model.canSendRelationshipRequest)

        await me.model.sendRelationshipRequest()

        let request = try #require(me.model.outgoingRequest)
        #expect(request.toNickname == "Dara")
        #expect(request.status == .pending)
        #expect(!me.model.canSendRelationshipRequest)
    }

    @Test func whenTheyAcceptHomeShowsTakenWithThePartner() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: true)

        await me.model.refreshOutgoingRequest()

        #expect(me.model.outgoingRequest?.status == .accepted)
        guard case .active(let partner, let since, _) = me.model.relationship else {
            Issue.record("expected an active Relationship, got \(me.model.relationship)")
            return
        }
        #expect(partner == "Dara")
        #expect(me.model.dayTogether(on: since) == 1)
        #expect(me.model.dayTogether(on: since.addingTimeInterval(12 * 86_400)) == 13)
    }

    @Test func homeKeepsShowingTakenAfterARelaunchBeforeTrusteeAnswers() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: true)
        await me.model.refreshOutgoingRequest()

        me.relaunch()

        guard case .active(let partner, _, _) = me.model.relationship else {
            Issue.record("expected the last known Relationship, got \(me.model.relationship)")
            return
        }
        #expect(partner == "Dara")
    }

    @Test func whenTheyDeclineNothingChanges() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: false)

        await me.model.refreshOutgoingRequest()

        #expect(me.model.outgoingRequest?.status == .declined)
        #expect(me.model.relationship == .none)
    }

    @Test func theRequestIsDisabledWithItsReasonWhenTheScannedPersonIsTaken() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: true)
        let vanna = TestPhone(nearby: dara)
        await vanna.onboard(as: "Vanna")

        await vanna.model.scan(try #require(dara.model.myLastysQR(at: Date())).payload)
        let requestsBefore = vanna.trusteeRequests
        await vanna.model.sendRelationshipRequest()

        #expect(vanna.model.scanResult?.requestBlock == .theyAreTaken)
        #expect(!vanna.model.canSendRelationshipRequest)
        #expect(vanna.model.outgoingRequest == nil)
        #expect(vanna.trusteeRequests == requestsBefore)
    }

    @Test func theRequestIsDisabledWithItsReasonWhenTheScannerIsTaken() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: true)
        let vanna = TestPhone(nearby: dara)
        await vanna.onboard(as: "Vanna")

        await me.model.scan(try #require(vanna.model.myLastysQR(at: Date())).payload)

        #expect(me.model.scanResult?.status == .single)
        #expect(me.model.scanResult?.requestBlock == .youAreTaken)
        #expect(!me.model.canSendRelationshipRequest)
    }

    @Test func closingTheScanKeepsFollowingAPendingRequestUntilHomeShowsTaken() async throws {
        let (dara, me) = try await meHavingScannedDara()
        await me.model.sendRelationshipRequest()

        me.model.dismissOutgoingRequest()
        me.model.clearScan()
        try await respond(as: dara, to: try #require(me.model.outgoingRequest), accept: true)
        await me.model.refreshOutgoingRequest()

        #expect(me.model.relationship != .none)
        me.model.dismissOutgoingRequest()
        #expect(me.model.outgoingRequest == nil)
    }

    @Test func scanningAgainForgetsAnEarlierRequestProblem() async throws {
        let (dara, me) = try await meHavingScannedDara()
        me.isOnline = false
        await me.model.sendRelationshipRequest()
        #expect(me.model.requestProblem == .needsInternet)

        me.isOnline = true
        await me.model.scan(try #require(dara.model.myLastysQR(at: Date())).payload)

        #expect(me.model.requestProblem == nil)
    }
}
