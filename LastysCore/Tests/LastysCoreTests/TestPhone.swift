import Foundation
@testable import LastysCore

/// A phone for tests: its stores live in a temp folder, so `relaunch()` really reloads from disk.
@MainActor
final class TestPhone {
    static let birthDate = Date(timeIntervalSince1970: 851_558_400) // 26 Dec 1996

    let folder: URL
    let key = SoftwarePhoneKey()
    private(set) var model: AppModel

    private var trusteeFile: URL { folder.appendingPathComponent("trustee.json") }
    /// Where the app keeps this phone's own state.
    var phoneFile: URL { folder.appendingPathComponent("phone.json") }
    /// Every request that has crossed into Trustee since the last launch, arguments included.
    var trusteeRequests: [String] { recorder.requests }
    private var recorder: RecordingTrustee

    init() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("lastys-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let launched = Self.launch(folder: folder, key: key)
        model = launched.0
        recorder = launched.1
    }

    /// Quits the app and opens it again with whatever this phone saved.
    func relaunch() {
        let launched = Self.launch(folder: folder, key: key)
        model = launched.0
        recorder = launched.1
    }

    /// Trustee already holds a Lastys ID for this phone's key, which the app itself doesn't know about.
    func trusteeAlreadyHoldsALastysIDForThisPhone() async throws {
        _ = try await FakeTrustee(savingTo: trusteeFile).client(forPhone: key.trusteeID).createLastysID()
        relaunch()
    }

    /// Goes through the intro, language and consent, stopping at the Recovery code.
    func createLastysID() async {
        model.skipIntro()
        model.confirmLanguage()
        model.isOver18 = true
        model.acceptsTerms = true
        await model.continueFromConsent()
    }

    /// Goes through all of onboarding to Home, as Srey Pich.
    func onboard() async {
        await createLastysID()
        model.hasSavedRecoveryCode = true
        model.continueFromRecoveryCode()
        model.profileNickname = "Srey Pich"
        model.profileBirthDate = Self.birthDate
        await model.finishProfile()
    }

    private static func launch(folder: URL, key: PhoneKey) -> (AppModel, RecordingTrustee) {
        let trustee = FakeTrustee(savingTo: folder.appendingPathComponent("trustee.json"))
        let recorder = RecordingTrustee(trustee.client(forPhone: key.trusteeID))
        let model = AppModel(
            phoneKey: key,
            trustee: recorder,
            store: FilePhoneStore(url: folder.appendingPathComponent("phone.json"))
        )
        return (model, recorder)
    }
}
