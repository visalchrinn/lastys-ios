import Foundation
@testable import LastysCore

/// A phone for tests: its stores live in a temp folder, so `relaunch()` really reloads from disk.
/// Phones made `nearby` another phone talk to the same Trustee, as two real phones would.
@MainActor
final class TestPhone {
    static let birthDate = Date(timeIntervalSince1970: 851_558_400) // 26 Dec 1996

    let folder: URL
    let key = SoftwarePhoneKey()
    let trustee: FakeTrustee
    /// One clock for this phone, its Trustee and every phone nearby.
    let clock: TestClock
    private let connectivity = SwitchableConnectivity()
    private(set) var model: AppModel
    private var recorder: RecordingTrustee

    /// Where the app keeps this phone's own state.
    var phoneFile: URL { folder.appendingPathComponent(Self.phoneFileName) }
    private static let phoneFileName = "phone.json"
    /// Every request that has crossed into Trustee since the last launch, arguments included.
    var trusteeRequests: [String] { recorder.requests }
    /// Whether the phone has internet.
    var isOnline: Bool {
        get { connectivity.isOnline }
        set { connectivity.isOnline = newValue }
    }

    /// Every reminder the phone has asked iOS to deliver.
    let reminders = RecordingReminderScheduler()
    private let calendar: Calendar

    /// - Parameters:
    ///   - moments: Moments already on the phone before it opens, e.g. Shared Moments, which only Trustee can create.
    ///   - calendar, now: the phone's calendar and the moment its clock starts at (shared with phones nearby).
    init(nearby other: TestPhone? = nil, moments: [Moment] = [], calendar: Calendar = .current, now: Date? = nil) {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("lastys-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let clock = other?.clock ?? TestClock(start: now ?? Date())
        self.clock = clock
        self.calendar = calendar
        if !moments.isEmpty {
            var seeded = PhoneState()
            seeded.moments = moments
            FilePhoneStore(url: folder.appendingPathComponent(Self.phoneFileName)).save(seeded)
        }
        trustee = other?.trustee ?? FakeTrustee(savingTo: folder.appendingPathComponent("trustee.json"), now: { clock.now })
        (model, recorder) = Self.open(
            key: key, trustee: trustee, phoneFile: folder.appendingPathComponent(Self.phoneFileName),
            connectivity: connectivity, reminders: reminders, calendar: calendar, clock: clock
        )
    }

    /// Quits the app and opens it again with whatever this phone saved.
    func relaunch() {
        (model, recorder) = Self.open(
            key: key, trustee: trustee, phoneFile: phoneFile, connectivity: connectivity,
            reminders: reminders, calendar: calendar, clock: clock
        )
    }

    /// Opens the app on this phone: what a launch builds from what the phone saved.
    private static func open(
        key: PhoneKey, trustee: FakeTrustee, phoneFile: URL, connectivity: Connectivity,
        reminders: ReminderScheduler, calendar: Calendar, clock: TestClock
    ) -> (AppModel, RecordingTrustee) {
        let recorder = RecordingTrustee(trustee.client(forPhone: key.trusteeID))
        let model = AppModel(
            phoneKey: key, trustee: recorder, store: FilePhoneStore(url: phoneFile),
            connectivity: connectivity, reminders: reminders, calendar: calendar, now: { clock.now }
        )
        return (model, recorder)
    }

    /// Trustee already holds a Lastys ID for this phone's key, which the app itself doesn't know about.
    func trusteeAlreadyHoldsALastysIDForThisPhone() async throws {
        _ = try await trustee.client(forPhone: key.trusteeID).createLastysID()
    }

    /// Goes through the intro, language and consent, stopping at the Recovery code.
    func createLastysID() async {
        model.skipIntro()
        model.confirmLanguage()
        model.isOver18 = true
        model.acceptsTerms = true
        await model.continueFromConsent()
    }

    /// Scans `other`, sends them a Relationship request, and has them accept it, so the two become Partners.
    func becomePartners(with other: TestPhone) async throws {
        guard let qr = other.model.myLastysQR(at: clock.now) else { throw TestPhoneError.notOnboarded }
        await model.scan(qr.payload)
        await model.sendRelationshipRequest()
        guard let request = model.outgoingRequest else { throw TestPhoneError.requestNotSent }
        try await other.trustee.client(forPhone: other.key.trusteeID).respondToRelationshipRequest(id: request.id, accept: true)
        await model.start()
        await other.model.start()
    }

    /// Goes through all of onboarding to Home.
    func onboard(as nickname: String = "Srey Pich") async {
        await createLastysID()
        model.hasSavedRecoveryCode = true
        model.continueFromRecoveryCode()
        model.profileNickname = nickname
        model.profileBirthDate = Self.birthDate
        await model.finishProfile()
    }

}

final class SwitchableConnectivity: Connectivity, @unchecked Sendable {
    private let lock = NSLock()
    private var online = true

    var isOnline: Bool {
        get { lock.withLock { online } }
        set { lock.withLock { online = newValue } }
    }
}

/// A clock tests move by hand. Starts at the real time, so Lastys QR codes made with `Date()` still scan.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(start: Date = Date()) {
        current = start
    }

    var now: Date { lock.withLock { current } }

    func advance(days: Double) {
        lock.withLock { current += days * 86_400 }
    }
}

enum TestPhoneError: Error {
    case notOnboarded
    case requestNotSent
}

/// Keeps the latest full set of reminders the phone asked for, as iOS would hold them.
final class RecordingReminderScheduler: ReminderScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var current: [Reminder] = []

    var scheduled: [Reminder] { lock.withLock { current } }

    func replaceAll(with reminders: [Reminder]) {
        lock.withLock { current = reminders }
    }
}
