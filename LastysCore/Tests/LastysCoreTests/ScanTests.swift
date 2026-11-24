import Foundation
import Testing
import LastysCore

@MainActor
struct ScanTests {
    private func twoPhones() async -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard(as: "Srey Pich")
        return (dara, me)
    }

    @Test func scanningASecondPhonesLiveLastysQRShowsThatLastysIDsScanResult() async throws {
        let (dara, me) = await twoPhones()
        let qr = try #require(dara.model.myLastysQR(at: Date()))

        await me.model.scan(qr.payload)

        let result = try #require(me.model.scanResult)
        #expect(result.nickname == "Dara")
        #expect(result.status == .single)
        #expect(result.idAgeDays == 0)
        #expect(result.isVeryNew)
        #expect(result.phoneTransferCount == 0)
        #expect(result.relationshipHistory == nil)
        #expect(me.model.scanProblem == nil)
    }

    @Test func withoutInternetAScanFailsClearlyAndNeverShowsAnEarlierResult() async throws {
        let (dara, me) = await twoPhones()
        let qr = try #require(dara.model.myLastysQR(at: Date()))
        await me.model.scan(qr.payload)
        let requestsBefore = me.trusteeRequests

        me.isOnline = false
        await me.model.scan(qr.payload)

        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == .needsInternet)
        #expect(me.trusteeRequests == requestsBefore)
    }

    @Test func anExpiredLastysQRIsRejected() async throws {
        let (dara, me) = await twoPhones()
        let screenshot = try #require(dara.model.myLastysQR(at: Date().addingTimeInterval(-10 * 60)))

        await me.model.scan(screenshot.payload)

        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == .expiredQR)
    }

    @Test func aForgedLastysQRIsRejected() async throws {
        let (dara, me) = await twoPhones()
        let daraID = try #require(dara.model.lastysID?.personalID)
        let forged = try LastysQRToken(personalID: daraID, at: Date(), signedBy: SoftwarePhoneKey())

        await me.model.scan(forged.text)

        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == .forgedQR)
    }

    @Test func aCodeThatIsNotALastysQRIsRejected() async {
        let (_, me) = await twoPhones()

        await me.model.scan("https://example.com")

        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == .notALastysQR)
    }

    @Test func closingTheScanResultForgetsIt() async throws {
        let (dara, me) = await twoPhones()
        await me.model.scan(try #require(dara.model.myLastysQR(at: Date())).payload)

        me.model.clearScan()

        #expect(me.model.scanResult == nil)
        #expect(me.model.scanProblem == nil)
    }

    @Test func aScanStillRunningWhenItIsClosedNeverShowsItsResultLater() async throws {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        let held = HeldTrustee(me.trustee.client(forPhone: me.key.trusteeID))
        let model = AppModel(
            phoneKey: me.key, trustee: held,
            store: FilePhoneStore(url: me.phoneFile), connectivity: SwitchableConnectivity()
        )
        let qr = try #require(dara.model.myLastysQR(at: Date()))

        let scanning = Task { await model.scan(qr.payload) }
        while held.heldScans == 0 { await Task.yield() }
        model.clearScan()
        held.release()
        await scanning.value

        #expect(model.scanResult == nil)
        #expect(model.scanProblem == nil)
        #expect(!model.isScanning)
    }
}
