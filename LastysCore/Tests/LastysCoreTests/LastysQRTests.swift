import Crypto
import Foundation
import Testing
@testable import LastysCore

@MainActor
struct LastysQRTests {
    /// 2026-11-29 05:00:15 UTC.
    private static let fifteenSecondsPastTheMinute = Date(timeIntervalSince1970: 1_795_928_415)

    @Test func myLastysQRIsSignedByThePhonesKeyAndCarriesTheLastysIDAndTheMinute() async throws {
        let phone = TestPhone()
        await phone.onboard()

        let qr = try #require(phone.model.myLastysQR(at: Self.fifteenSecondsPastTheMinute))
        let token = try #require(LastysQRToken(parsing: qr.payload))

        #expect(token.personalID == phone.model.lastysID?.personalID)
        #expect(token.minute == 29_932_140) // whole minutes since 1970
        #expect(token.isSigned(by: phone.key.publicKey))
        #expect(!token.isSigned(by: SoftwarePhoneKey().publicKey))
    }

    @Test func aTokenWithAChangedMinuteNoLongerMatchesItsSignature() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let qr = try #require(phone.model.myLastysQR(at: Self.fifteenSecondsPastTheMinute))

        let forged = qr.payload.replacingOccurrences(of: ".29932140.", with: ".29932150.")

        let token = try #require(LastysQRToken(parsing: forged))
        #expect(!token.isSigned(by: phone.key.publicKey))
    }

    @Test func myLastysQRStaysTheSameWithinAMinuteAndCountsDownToTheNext() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let start = Self.fifteenSecondsPastTheMinute

        let at15 = try #require(phone.model.myLastysQR(at: start))
        let at59 = try #require(phone.model.myLastysQR(at: start.addingTimeInterval(44.9)))

        #expect(at15.secondsUntilNextCode == 45)
        #expect(at59.secondsUntilNextCode == 1)
        #expect(at59.payload == at15.payload)
    }

    @Test func myLastysQRChangesAtTheMinuteBoundary() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let lastMoment = Self.fifteenSecondsPastTheMinute.addingTimeInterval(44.9)
        let nextMinute = Self.fifteenSecondsPastTheMinute.addingTimeInterval(45)

        let before = try #require(phone.model.myLastysQR(at: lastMoment))
        let after = try #require(phone.model.myLastysQR(at: nextMinute))

        #expect(after.payload != before.payload)
        #expect(after.secondsUntilNextCode == 60)
        let token = try #require(LastysQRToken(parsing: after.payload))
        #expect(token.minute == 29_932_141)
        #expect(token.isSigned(by: phone.key.publicKey))
    }

    @Test func showingMyLastysQRMakesNoRequestToTrustee() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let requestsBefore = phone.trusteeRequests

        for second in 0..<120 {
            _ = try #require(phone.model.myLastysQR(at: Self.fifteenSecondsPastTheMinute.addingTimeInterval(Double(second))))
        }

        #expect(phone.trusteeRequests == requestsBefore)
    }

    @Test func thereIsNoLastysQRBeforeTheLastysIDExists() {
        let phone = TestPhone()

        #expect(phone.model.myLastysQR(at: Self.fifteenSecondsPastTheMinute) == nil)
    }

    @Test func scannersSeeStatusOnlyByDefault() async {
        let phone = TestPhone()
        await phone.onboard()

        #expect(phone.model.shareLevel == .statusOnly)
    }

    @Test func aTokenIsReadOnlyInItsExactTextForm() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let qr = try #require(phone.model.myLastysQR(at: Self.fifteenSecondsPastTheMinute))

        // The same minute written with a leading zero: the fake must refuse what the real Trustee refuses.
        let padded = qr.payload.replacingOccurrences(of: ".29932140.", with: ".029932140.")

        #expect(LastysQRToken(parsing: padded) == nil)
        #expect(LastysQRToken(parsing: qr.payload)?.text == qr.payload)
    }
}
