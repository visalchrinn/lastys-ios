import Foundation

/// Everything this phone keeps about its own Lastys ID between launches.
/// The birth date lives only here: it never goes to Trustee.
public struct PhoneState: Codable, Equatable, Sendable {
    public var language: Language = .khmer
    public var lastysID: LastysID?
    public var recoveryCode: String?
    public var hasSavedRecoveryCode = false
    public var nickname: String?
    public var photo: Data?
    public var birthDate: Date?
    public var hasFinishedOnboarding = false

    public init() {}
}

/// The app's language. Khmer is the default; English is available.
public enum Language: String, Codable, CaseIterable, Sendable {
    case khmer = "km"
    case english = "en"
}

/// Where the phone keeps `PhoneState`.
public protocol PhoneStore: Sendable {
    func load() -> PhoneState?
    func save(_ state: PhoneState)
}

/// Keeps `PhoneState` as a JSON file, encrypted until the phone is first unlocked.
public struct FilePhoneStore: PhoneStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> PhoneState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PhoneState.self, from: data)
    }

    public func save(_ state: PhoneState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.writeAtomicallyProtected(to: url)
    }
}

/// Keeps `PhoneState` in memory only, for previews and tests.
public final class InMemoryPhoneStore: PhoneStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: PhoneState?

    public init(_ state: PhoneState? = nil) {
        self.state = state
    }

    public func load() -> PhoneState? {
        lock.withLock { state }
    }

    public func save(_ state: PhoneState) {
        lock.withLock { self.state = state }
    }
}

extension Data {
    /// Writes atomically, creating the folder if needed. On iOS the file is unreadable until the phone is first
    /// unlocked after a restart, and is left out of backups.
    func writeAtomicallyProtected(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Kept out of iCloud and computer backups: it holds the Recovery code, and a backup can't
        // restore a Lastys ID anyway, because the phone's key never leaves the phone (ADR 0003).
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = url
        try excluded.setResourceValues(values)
        #else
        try write(to: url, options: .atomic)
        #endif
    }
}
