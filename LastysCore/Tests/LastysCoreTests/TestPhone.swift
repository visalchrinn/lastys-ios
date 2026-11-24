import Foundation
@testable import LastysCore

/// A phone for tests: its stores live in a temp folder, so `relaunch()` really reloads from disk.
@MainActor
final class TestPhone {
    let folder: URL
    let phoneKey: String
    private(set) var model: AppModel

    private var trusteeFile: URL { folder.appendingPathComponent("trustee.json") }

    init(phoneKey: String = "phone-a") {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("lastys-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.phoneKey = phoneKey
        model = Self.launch(folder: folder, phoneKey: phoneKey)
    }

    /// Quits the app and opens it again with whatever this phone saved.
    func relaunch() {
        model = Self.launch(folder: folder, phoneKey: phoneKey)
    }

    /// Trustee already holds a Lastys ID for this phone's key, which the app itself doesn't know about.
    func trusteeAlreadyHoldsALastysIDForThisPhone() async throws {
        _ = try await FakeTrustee(savingTo: trusteeFile).client(forPhone: phoneKey).createLastysID()
        relaunch()
    }

    private static func launch(folder: URL, phoneKey: String) -> AppModel {
        let trustee = FakeTrustee(savingTo: folder.appendingPathComponent("trustee.json"))
        return AppModel(
            trustee: trustee.client(forPhone: phoneKey),
            store: FilePhoneStore(url: folder.appendingPathComponent("phone.json"))
        )
    }
}
