import Foundation
import Testing
import LastysCore

@MainActor
struct PhoneMoveTests {
    private let momsBirthday = MomentDraft(
        type: .birthday, title: "Mom's birthday", date: Date().addingTimeInterval(20 * 86_400), repeatsOnKhmerLunarDate: false
    )

    /// Me, onboarded with a personal Moment, and a new phone nearby that holds no Lastys ID yet.
    private func meAndANewPhone() async -> (old: TestPhone, new: TestPhone) {
        let old = TestPhone()
        await old.onboard()
        old.model.addMoment(momsBirthday)
        let new = TestPhone(nearby: old)
        return (old, new)
    }

    // MARK: Phone transfer

    @Test func aPhoneTransferMovesTheLastysIDAndMyPhonesDataToTheNewPhone() async throws {
        let (old, new) = await meAndANewPhone()
        let lastysID = old.model.lastysID
        let recoveryCode = old.model.recoveryCode

        await old.model.offerPhoneTransfer()
        let qr = try #require(old.model.phoneTransferQR)
        new.model.startMovingFromAnotherPhone()
        #expect(new.model.screen == .onboarding(.moveFromAnotherPhone))
        await new.model.receivePhoneTransfer(qr.payload)

        #expect(new.model.screen == .home)
        #expect(new.model.lastysID == lastysID)
        #expect(new.model.nickname == "Srey Pich")
        #expect(new.model.birthDate == TestPhone.birthDate)
        #expect(new.model.recoveryCode == recoveryCode)
        #expect(new.model.moments.map(\.title) == ["Mom's birthday"])

        await old.model.start()
        #expect(old.model.screen == .onboarding(.intro(page: 0)))
        #expect(old.model.lastysID == nil)
        #expect(old.model.lastysIDMovedAway)
        #expect(old.model.moments.isEmpty)
    }

    @Test func trusteeOnlyEverHoldsASealedBundle() async throws {
        let (old, _) = await meAndANewPhone()

        await old.model.offerPhoneTransfer()
        let qr = try #require(old.model.phoneTransferQR)
        let code = String(qr.payload.split(separator: ".")[1])
        let moved = try await old.trustee.client(forPhone: "someone-else").completePhoneTransfer(code: code)

        let bytes = String(decoding: moved.sealedBundle, as: UTF8.self)
        #expect(!bytes.contains("Mom's birthday"))
        #expect(!old.trusteeRequests.contains { $0.contains("Mom's birthday") })
    }

    @Test func aSecondPhoneTransferWithin30DaysIsRefused() async throws {
        let (old, new) = await meAndANewPhone()
        await old.model.offerPhoneTransfer()
        new.model.startMovingFromAnotherPhone()
        await new.model.receivePhoneTransfer(try #require(old.model.phoneTransferQR).payload)

        await new.model.offerPhoneTransfer()

        #expect(new.model.phoneTransferQR == nil)
        #expect(new.model.phoneMoveProblem == .transferTooSoon)
    }

    @Test func aTransferQRMoreThan5MinutesOldIsRefused() async throws {
        let (old, new) = await meAndANewPhone()
        await old.model.offerPhoneTransfer()
        let qr = try #require(old.model.phoneTransferQR)

        old.clock.advance(days: 6.0 / 1_440)
        new.model.startMovingFromAnotherPhone()
        await new.model.receivePhoneTransfer(qr.payload)

        #expect(new.model.phoneMoveProblem == .transferCodeExpired)
        #expect(new.model.lastysID == nil)
    }

    @Test func somethingThatIsNotATransferQRIsRefused() async {
        let (_, new) = await meAndANewPhone()
        new.model.startMovingFromAnotherPhone()

        await new.model.receivePhoneTransfer("https://example.com")

        #expect(new.model.phoneMoveProblem == .notATransferQR)
    }

    @Test func thePartnerIsToldWhenMyLastysIDChangesPhone() async throws {
        let (old, new) = await meAndANewPhone()
        let dara = TestPhone(nearby: old)
        await dara.onboard(as: "Dara")
        try await old.becomePartners(with: dara)

        await old.model.offerPhoneTransfer()
        new.model.startMovingFromAnotherPhone()
        await new.model.receivePhoneTransfer(try #require(old.model.phoneTransferQR).payload)
        await dara.model.start()

        #expect(dara.reminders.notices == [.partnerChangedPhone])
        #expect(dara.model.relationship != .none)
    }

    // MARK: Recovery

    @Test func aRecoveryWaits7DaysAndMovesTheLastysIDWithANewRecoveryCode() async throws {
        let (old, new) = await meAndANewPhone()
        let lastysID = old.model.lastysID
        let oldCode = try #require(old.model.recoveryCode)

        new.model.startRecoveryWithCode()
        await new.model.beginRecovery(code: oldCode)
        guard case .onboarding(.waitingForRecovery) = new.model.screen else {
            Issue.record("expected the Recovery wait, got \(new.model.screen)")
            return
        }
        new.relaunch()
        await new.model.checkRecovery()
        #expect(new.model.screen == .onboarding(.waitingForRecovery))
        #expect(new.model.recoveryCompletesAt == new.clock.now.addingTimeInterval(7 * 86_400))

        new.clock.advance(days: 7)
        await new.model.checkRecovery()

        #expect(new.model.lastysID == lastysID)
        #expect(new.model.screen == .onboarding(.recoveryCode))
        #expect(new.model.recoveryCode != nil && new.model.recoveryCode != oldCode)
        await old.model.start()
        #expect(old.model.lastysIDMovedAway)
    }

    @Test func theCurrentPhoneIsToldAndCanCancelARecovery() async throws {
        let (old, new) = await meAndANewPhone()
        new.model.startRecoveryWithCode()
        await new.model.beginRecovery(code: try #require(old.model.recoveryCode))

        await old.model.start()
        await old.model.refreshMe()
        #expect(old.reminders.notices == [.recoveryStarted])
        #expect(old.model.myDetails?.recoveryCompletesAt != nil)

        await old.model.cancelRecovery()
        #expect(old.model.myDetails?.recoveryCompletesAt == nil)

        await new.model.checkRecovery()
        #expect(new.model.screen == .onboarding(.intro(page: 0)))
        #expect(new.model.phoneMoveProblem == .recoveryCancelled)
        old.clock.advance(days: 7)
        await old.model.start()
        #expect(old.model.lastysID != nil)
    }

    @Test func aWrongRecoveryCodeStartsNothing() async {
        let (_, new) = await meAndANewPhone()
        new.model.startRecoveryWithCode()

        await new.model.beginRecovery(code: "AAAA-BBBB-CCCC-DDDD")

        #expect(new.model.phoneMoveProblem == .wrongRecoveryCode)
        #expect(new.model.screen == .onboarding(.enterRecoveryCode))
    }

    @Test func thePartnerIsToldWhenARecoveryStarts() async throws {
        let (old, new) = await meAndANewPhone()
        let dara = TestPhone(nearby: old)
        await dara.onboard(as: "Dara")
        try await old.becomePartners(with: dara)

        new.model.startRecoveryWithCode()
        await new.model.beginRecovery(code: try #require(old.model.recoveryCode))
        await dara.model.start()

        #expect(dara.reminders.notices == [.partnerStartedRecovery])
    }

    @Test func aTransferQRWithABrokenKeyIsRefusedBeforeTheCodeIsSpent() async throws {
        let (old, new) = await meAndANewPhone()
        await old.model.offerPhoneTransfer()
        let qr = try #require(old.model.phoneTransferQR)
        let parts = qr.payload.split(separator: ".").map(String.init)
        new.model.startMovingFromAnotherPhone()

        await new.model.receivePhoneTransfer("\(parts[0]).\(parts[1]).c2hvcnQ")
        #expect(new.model.phoneMoveProblem == .notATransferQR)
        #expect(new.model.lastysID == nil)

        await new.model.receivePhoneTransfer(qr.payload)
        #expect(new.model.lastysID == old.model.lastysID)
    }

    @Test func ifTheMovedDataCannotBeOpenedThePersonIsTold() async throws {
        let (old, new) = await meAndANewPhone()
        await old.model.offerPhoneTransfer()
        let parts = try #require(old.model.phoneTransferQR).payload.split(separator: ".").map(String.init)
        let wrongKey = Data(repeating: 7, count: 32).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        new.model.startMovingFromAnotherPhone()

        await new.model.receivePhoneTransfer("\(parts[0]).\(parts[1]).\(wrongKey)")

        #expect(new.model.lastysID != nil)
        #expect(new.model.phoneMoveProblem == .someDataDidNotMove)
        #expect(new.model.moments.isEmpty)
    }

    @Test func theModelSaysHowLongATransferCodeHasLeft() async throws {
        let (old, _) = await meAndANewPhone()
        await old.model.offerPhoneTransfer()

        #expect(old.model.phoneTransferSecondsLeft(at: old.clock.now) == 300)
        #expect(old.model.phoneTransferSecondsLeft(at: old.clock.now.addingTimeInterval(400)) == 0)
    }
}
