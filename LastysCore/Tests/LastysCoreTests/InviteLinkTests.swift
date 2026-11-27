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

    @Test func makingALinkNeedsInternet() async throws {
        let me = await single()
        me.isOnline = false

        await me.model.openInvite()

        #expect(me.model.inviteLink == nil)
        #expect(me.model.inviteProblem == .needsInternet)
    }
}
