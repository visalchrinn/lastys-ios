import Crypto
import Foundation
import Testing
@testable import LastysCore

@MainActor
struct LastysQRTests {
    @Test func myLastysQRIsSignedByThePhonesKeyAndCarriesTheLastysIDAndTheQRNumber() async throws {
        let phone = TestPhone()
        await phone.onboard()

        let qr = try #require(phone.model.myLastysQR())
        let token = try #require(LastysQRToken(parsing: qr.payload))

        #expect(token.personalID == phone.model.lastysID?.personalID)
        #expect(token.number == 0)
        #expect(token.isSigned(by: phone.key.publicKey))
        #expect(!token.isSigned(by: SoftwarePhoneKey().publicKey))
    }

    @Test func aTokenWithAChangedQRNumberNoLongerMatchesItsSignature() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let qr = try #require(phone.model.myLastysQR())

        let forged = qr.payload.replacingOccurrences(of: ".0.", with: ".1.")

        let token = try #require(LastysQRToken(parsing: forged))
        #expect(!token.isSigned(by: phone.key.publicKey))
    }

    @Test func myLastysQRNeverChangesOnItsOwn() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let first = try #require(phone.model.myLastysQR())

        phone.clock.advance(days: 30)

        #expect(try #require(phone.model.myLastysQR()) == first)
    }

    @Test func showingMyLastysQRMakesNoRequestToTrustee() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let requestsBefore = phone.trusteeRequests

        for _ in 0..<120 { _ = try #require(phone.model.myLastysQR()) }

        #expect(phone.trusteeRequests == requestsBefore)
    }

    @Test func thereIsNoLastysQRBeforeTheLastysIDExists() {
        let phone = TestPhone()

        #expect(phone.model.myLastysQR() == nil)
    }

    @Test func revokingMakesANewQRAndTheOldOneStopsScanning() async throws {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        let old = try #require(dara.model.myLastysQR())
        await me.model.scan(old.payload)
        #expect(me.model.scanResult?.nickname == "Dara")

        await dara.model.revokeMyLastysQR()
        let new = try #require(dara.model.myLastysQR())
        await me.model.scan(old.payload)

        #expect(new.payload != old.payload)
        #expect(LastysQRToken(parsing: new.payload)?.number == 1)
        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == .revokedQR)

        await me.model.scan(new.payload)
        #expect(me.model.scanResult?.nickname == "Dara")
    }

    @Test func eachRevokeRetiresTheLastOne() async throws {
        let phone = TestPhone()
        await phone.onboard()

        await phone.model.revokeMyLastysQR()
        await phone.model.revokeMyLastysQR()

        #expect(LastysQRToken(parsing: try #require(phone.model.myLastysQR()).payload)?.number == 2)
    }

    @Test func revokingNeedsInternetAndKeepsTheCurrentQR() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let before = try #require(phone.model.myLastysQR())
        phone.isOnline = false

        await phone.model.revokeMyLastysQR()

        #expect(phone.model.qrProblem == .needsInternet)
        #expect(try #require(phone.model.myLastysQR()) == before)
    }

    @Test func theNewQRSurvivesRestartingTheApp() async throws {
        let phone = TestPhone()
        await phone.onboard()
        await phone.model.revokeMyLastysQR()

        phone.relaunch()

        let qr = try #require(phone.model.myLastysQR())
        let token = try #require(LastysQRToken(parsing: qr.payload))
        #expect(token.number == 1)
        #expect(token.isSigned(by: phone.key.publicKey))
    }

    @Test func scannersSeeStatusOnlyByDefault() async {
        let phone = TestPhone()
        await phone.onboard()

        #expect(phone.model.shareLevel == .statusOnly)
    }

    @Test func aTokenIsReadOnlyInItsExactTextForm() async throws {
        let phone = TestPhone()
        await phone.onboard()
        let qr = try #require(phone.model.myLastysQR())

        // The QR number written with a leading zero: the fake must refuse what the real Trustee refuses.
        let padded = qr.payload.replacingOccurrences(of: ".0.", with: ".00.")

        #expect(LastysQRToken(parsing: padded) == nil)
        #expect(LastysQRToken(parsing: qr.payload)?.text == qr.payload)
    }
}
