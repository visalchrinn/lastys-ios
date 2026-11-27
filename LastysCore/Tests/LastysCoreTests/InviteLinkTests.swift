import Foundation
import Testing
import LastysCore

/// The sender's side of an Invite link (#37). Accepting and declining are #39.
@MainActor
struct InviteLinkTests {
    private func single() async -> TestPhone {
        let me = TestPhone()
        await me.onboard()
        return me
    }

    private func partners() async throws -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        try await me.becomePartners(with: dara)
        return (dara, me)
    }

    private func trustee(of phone: TestPhone) -> TrusteeClient {
        phone.trustee.client(forPhone: phone.key.trusteeID)
    }

    @Test func aVerifiedSinglePersonCanMakeAnInviteLinkThatLastsSevenDays() async throws {
        let me = await single()
        #expect(me.model.canInvite)

        await me.model.openInvite()

        let link = try #require(me.model.inviteLink)
        #expect(link.url.hasPrefix("lastys.app/i/"))
        #expect(link.expiresAt == me.clock.now.addingTimeInterval(7 * 86_400))
        #expect(!me.model.isInviteSent)
    }

    @Test func copyingOrSharingTheLinkMeansItIsSentAndWaiting() async throws {
        let me = await single()
        await me.model.openInvite()

        me.model.inviteWasSent()

        #expect(me.model.isInviteSent)
    }

    @Test func aWaitingLinkSurvivesARelaunch() async throws {
        let me = await single()
        await me.model.openInvite()
        me.model.inviteWasSent()
        let code = try #require(me.model.inviteLink?.code)

        me.relaunch()
        await me.model.start()

        #expect(me.model.inviteLink?.code == code)
        #expect(me.model.isInviteSent)
    }

    @Test func onlyOneLinkWaitsAtATime() async throws {
        let me = await single()
        await me.model.openInvite()
        let first = try #require(me.model.inviteLink)

        await me.model.openInvite()

        #expect(me.model.inviteLink == first)
        await #expect(throws: TrusteeError.inviteAlreadyWaiting) {
            _ = try await trustee(of: me).createInviteLink()
        }
    }

    @Test func cancellingStopsTheLinkAtTrusteeAndAllowsANewOne() async throws {
        let me = await single()
        await me.model.openInvite()
        me.model.inviteWasSent()
        let first = try #require(me.model.inviteLink)

        await me.model.cancelInvite()

        #expect(me.model.inviteLink == nil)
        #expect(!me.model.isInviteSent)
        #expect(try await trustee(of: me).myInviteLink() == nil)
        await me.model.openInvite()
        #expect(me.model.inviteLink?.code != first.code)
    }

    @Test func aLinkOlderThanSevenDaysIsNoLongerWaiting() async throws {
        let me = await single()
        await me.model.openInvite()
        me.model.inviteWasSent()

        me.clock.advance(days: 7)
        await me.model.start()

        #expect(me.model.inviteLink == nil)
        #expect(!me.model.isInviteSent)
    }

    @Test func theInviteIsNotOfferedWhileTaken() async throws {
        let (_, me) = try await partners()

        #expect(!me.model.canInvite)
        await me.model.openInvite()
        #expect(me.model.inviteLink == nil)
        await #expect(throws: TrusteeError.youAreTaken) {
            _ = try await trustee(of: me).createInviteLink()
        }
    }

    @Test func theInviteIsNotOfferedDuringACoolingOffPeriod() async throws {
        let (dara, me) = try await partners()
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        #expect(!me.model.canInvite)
        await #expect(throws: TrusteeError.youAreCoolingOff) {
            _ = try await trustee(of: me).createInviteLink()
        }
    }

    // MARK: The partner accepts or declines (#39)

    /// Me, single, having sent an Invite link; and Dara, who has Lastys, about to open it.
    private func meHavingInvitedDara() async throws -> (dara: TestPhone, me: TestPhone, code: String) {
        let me = TestPhone()
        await me.onboard(as: "Srey Pich")
        await me.model.openInvite()
        me.model.inviteWasSent()
        let code = try #require(me.model.inviteLink?.code)
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        return (dara, me, code)
    }

    private func onboarded(_ nickname: String, nearby other: TestPhone) async -> TestPhone {
        let phone = TestPhone(nearby: other)
        await phone.onboard(as: nickname)
        return phone
    }

    private static let linkingTitles = ["Our 1st anniversary", "The day we linked"]

    @Test func thePartnerSeesWhoIsAskingBeforeAnswering() async throws {
        let (dara, _, code) = try await meHavingInvitedDara()

        await dara.model.lookUpInvite(code: code)

        #expect(dara.model.receivedInvite == ReceivedInvite(code: code, senderNickname: "Srey Pich"))
        #expect(dara.model.receivedInviteProblem == nil)
    }

    @Test func acceptingMakesBothTakenAndGivesTheSenderTheLinkingMoments() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        await dara.model.lookUpInvite(code: code)

        await dara.model.acceptInvite()
        await me.model.start()

        guard case .active(let mine, _, _) = me.model.relationship, case .active(let darasPartner, _, _) = dara.model.relationship else {
            Issue.record("expected both Taken, got \(me.model.relationship) and \(dara.model.relationship)")
            return
        }
        #expect(mine == "Dara")
        #expect(darasPartner == "Srey Pich")
        #expect(me.model.moments.map(\.title).sorted() == Self.linkingTitles)
        #expect(me.model.moments.allSatisfy { $0.isShared })
        #expect(dara.model.moments.isEmpty)
        #expect(me.model.inviteLink == nil)
        #expect(!me.model.isInviteSent)
        #expect(dara.model.receivedInvite == nil)
    }

    @Test func checkingAgainAfterAcceptanceAddsNoDuplicates() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        await dara.model.lookUpInvite(code: code)
        await dara.model.acceptInvite()

        await me.model.checkInvite()
        await me.model.start()
        me.relaunch()
        await me.model.start()

        #expect(me.model.moments.map(\.title).sorted() == Self.linkingTitles)
    }

    @Test func notNowTellsTheSenderAndFreesThemToSendANewInvite() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        await dara.model.lookUpInvite(code: code)

        await dara.model.declineInvite()
        await me.model.checkInvite()

        #expect(me.model.inviteDeclined)
        #expect(me.model.inviteLink == nil)
        #expect(!me.model.isInviteSent)
        #expect(me.model.relationship == .none)
        #expect(dara.model.relationship == .none)
        await me.model.openInvite()
        #expect(me.model.inviteLink?.code != code)
        #expect(!me.model.inviteDeclined)
    }

    @Test func aLinkWorksForOnePersonOnly() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        let vanna = await onboarded("Vanna", nearby: me)
        await dara.model.lookUpInvite(code: code)
        await dara.model.acceptInvite()

        await vanna.model.lookUpInvite(code: code)

        #expect(vanna.model.receivedInvite == nil)
        #expect(vanna.model.receivedInviteProblem == .noLongerValid)
        await #expect(throws: TrusteeError.inviteNotValid) {
            try await trustee(of: vanna).acceptInvite(code: code)
        }
    }

    @Test func aLinkOlderThanSevenDaysCannotBeAccepted() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        me.clock.advance(days: 7)

        await dara.model.lookUpInvite(code: code)

        #expect(dara.model.receivedInviteProblem == .noLongerValid)
        await #expect(throws: TrusteeError.inviteNotValid) {
            try await trustee(of: dara).acceptInvite(code: code)
        }
    }

    @Test func aCancelledLinkCannotBeAccepted() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        await me.model.cancelInvite()

        await dara.model.lookUpInvite(code: code)

        #expect(dara.model.receivedInviteProblem == .noLongerValid)
    }

    @Test func aWaitingLinkStopsWorkingOnceTheSenderIsTakenAnotherWay() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        let vanna = await onboarded("Vanna", nearby: me)
        try await me.becomePartners(with: vanna)
        await dara.model.lookUpInvite(code: code)

        #expect(dara.model.receivedInviteProblem == .noLongerValid)
        await #expect(throws: TrusteeError.inviteNotValid) {
            try await trustee(of: dara).acceptInvite(code: code)
        }
        #expect(me.model.inviteLink == nil)
        #expect(me.model.moments.count == 2)
    }

    @Test func aTakenPartnerCannotAccept() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        let vanna = await onboarded("Vanna", nearby: me)
        try await dara.becomePartners(with: vanna)
        await dara.model.lookUpInvite(code: code)

        await dara.model.acceptInvite()

        #expect(dara.model.receivedInviteProblem == .youAreTaken)
        await me.model.start()
        #expect(me.model.relationship == .none)
        #expect(me.model.inviteLink?.code == code)
    }

    @Test func aPartnerInACoolingOffPeriodCannotAccept() async throws {
        let (dara, me, code) = try await meHavingInvitedDara()
        let vanna = await onboarded("Vanna", nearby: me)
        try await dara.becomePartners(with: vanna)
        await dara.model.perform(.sendEndRequest)
        await vanna.model.start()
        await vanna.model.perform(.agreeToEndRequest)
        await dara.model.start()
        await dara.model.lookUpInvite(code: code)

        await dara.model.acceptInvite()

        #expect(dara.model.receivedInviteProblem == .youAreCoolingOff)
        #expect(dara.model.relationship != .none)
    }

    @Test func nobodyCanAcceptTheirOwnInvite() async throws {
        let (_, me, code) = try await meHavingInvitedDara()

        await me.model.lookUpInvite(code: code)

        #expect(me.model.receivedInviteProblem == .thatIsYou)
    }

    @Test func makingALinkNeedsInternet() async throws {
        let me = await single()
        me.isOnline = false

        await me.model.openInvite()

        #expect(me.model.inviteLink == nil)
        #expect(me.model.inviteProblem == .needsInternet)
    }
}
