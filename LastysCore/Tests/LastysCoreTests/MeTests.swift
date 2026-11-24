import Foundation
import Testing
import LastysCore

@MainActor
struct MeTests {
    private func meAndDara() async -> (me: TestPhone, dara: TestPhone) {
        let me = TestPhone()
        await me.onboard()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        return (me, dara)
    }

    private func daraScans(_ me: TestPhone, _ dara: TestPhone) async throws -> ScanResult {
        await dara.model.scan(try #require(me.model.myLastysQR(at: me.clock.now)).payload)
        return try #require(dara.model.scanResult)
    }

    @Test func aNewLastysIDSharesStatusOnly() async {
        let (me, _) = await meAndDara()

        await me.model.refreshMe()

        #expect(me.model.shareLevel == .statusOnly)
        #expect(me.model.myDetails?.shareLevel == .statusOnly)
        #expect(me.model.myDetails?.phoneTransferCount == 0)
        #expect(me.model.myDetails?.createdAt == me.clock.now)
    }

    @Test func switchingTheShareLevelChangesTheNextScan() async throws {
        let (me, dara) = await meAndDara()
        #expect(try await daraScans(me, dara).relationshipHistory == nil)

        await me.model.setShareLevel(.statusAndHistory)

        #expect(me.model.shareLevel == .statusAndHistory)
        #expect(try await daraScans(me, dara).relationshipHistory == [])
    }

    @Test func whoScannedMeShowsOnlyWhen() async throws {
        let (me, dara) = await meAndDara()
        _ = try await daraScans(me, dara)

        await me.model.refreshMe()

        #expect(me.model.whoScannedMe == [me.clock.now])
    }

    @Test func theRecoveryCodeIsShownOnlyAfterDeviceAuthentication() async {
        let (me, _) = await meAndDara()
        #expect(me.model.revealedRecoveryCode == nil)

        me.authenticator.allows = false
        await me.model.revealRecoveryCode()
        #expect(me.model.revealedRecoveryCode == nil)
        #expect(me.model.meProblem == .notAuthenticated)

        me.authenticator.allows = true
        await me.model.revealRecoveryCode()
        #expect(me.model.revealedRecoveryCode == me.model.recoveryCode)
        #expect(me.model.revealedRecoveryCode != nil)

        me.model.hideRecoveryCode()
        #expect(me.model.revealedRecoveryCode == nil)
    }

    @Test func aNewRecoveryCodeNeedsAuthenticationAndTheOldOneStopsWorking() async throws {
        let (me, _) = await meAndDara()
        let old = try #require(me.model.recoveryCode)

        me.authenticator.allows = false
        await me.model.makeNewRecoveryCode()
        #expect(me.model.recoveryCode == old)

        me.authenticator.allows = true
        await me.model.makeNewRecoveryCode()
        let new = try #require(me.model.recoveryCode)
        #expect(new != old)
        #expect(me.model.revealedRecoveryCode == new)

        let newPhone = me.trustee.client(forPhone: "a-new-phone")
        await #expect(throws: TrusteeError.wrongRecoveryCode) {
            try await newPhone.startRecovery(recoveryCode: old)
        }
        _ = try await newPhone.startRecovery(recoveryCode: new)
    }

    @Test func editingTheProfileChangesTheScanButTheBirthDateStaysOnThePhone() async throws {
        let (me, dara) = await meAndDara()
        let newBirthDate = Date(timeIntervalSince1970: 800_000_000)
        let requestsBefore = me.trusteeRequests

        let saved = await me.model.saveProfile(nickname: "  Pich  ", photo: nil, birthDate: newBirthDate)

        #expect(saved)
        #expect(me.model.nickname == "Pich")
        #expect(me.model.birthDate == newBirthDate)
        #expect(try await daraScans(me, dara).nickname == "Pich")
        let sent = me.trusteeRequests.dropFirst(requestsBefore.count)
        #expect(!sent.contains { $0.contains("800000000") || $0.contains("1995") })
    }

    @Test func aProfileNeedsANickname() async {
        let (me, _) = await meAndDara()

        let saved = await me.model.saveProfile(nickname: "   ", photo: nil, birthDate: TestPhone.birthDate)

        #expect(!saved)
        #expect(me.model.nickname == "Srey Pich")
    }

    @Test func theNicknameRuleComesFromTheModel() async {
        let (me, _) = await meAndDara()

        #expect(!me.model.canSaveProfile(nickname: " \n "))
        #expect(me.model.canSaveProfile(nickname: "Pich"))
    }

    @Test func aNewLastysIDHasAWorkingRecoveryCode() async {
        let (me, _) = await meAndDara()

        await me.model.refreshMe()

        #expect(me.model.myDetails?.hasRecoveryCode == true)
        #expect(!me.model.needsNewRecoveryCode)
    }

    @Test func aLastysIDFromBeforeRecoveryCodesWereCheckedIsAskedToMakeANewOne() async throws {
        let me = TestPhone()
        await me.onboard()
        // A Lastys ID made by an earlier build: Trustee has no Recovery code on file for it.
        try await me.trustee.forgetRecoveryCodeForTesting(of: try #require(me.model.lastysID?.personalID))

        await me.model.refreshMe()
        #expect(me.model.needsNewRecoveryCode)

        await me.model.makeNewRecoveryCode()
        await me.model.refreshMe()
        #expect(!me.model.needsNewRecoveryCode)
    }

    @Test func offlineANewRecoveryCodeDoesNotAskForFaceIDFirst() async {
        let (me, _) = await meAndDara()
        me.isOnline = false
        me.authenticator.allows = false

        await me.model.makeNewRecoveryCode()

        #expect(me.model.meProblem == .needsInternet)
    }
}
