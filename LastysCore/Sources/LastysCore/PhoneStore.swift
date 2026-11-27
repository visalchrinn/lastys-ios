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
    /// What a Scan of this Lastys ID shows. Trustee applies it; the phone keeps a copy to show the person.
    public var shareLevel: ShareLevel = .statusOnly
    /// The last Relationship status Trustee gave.
    public var relationship: RelationshipStatus = .none
    /// Quick hide: the status card and Shared Moments stay off this phone's screen. Never sent to Trustee.
    public var isQuickHideOn = false
    /// Personal Moments live only here, never on Trustee.
    public var moments: [Moment] = []
    /// What the Partner shares, as Trustee last gave it.
    public var partnerMoments: [SharedMoment] = []
    /// After an ending: this person's copy of what the former Partner shared, until they keep or delete it.
    public var formerPartnerMoments: [SharedMoment] = []
    /// Whether Trustee holds Moments this phone shared, so un-sharing the last one still reaches it.
    public var hasSharedMoments = false
    /// My own Moments that were shared when my Relationship ended, waiting for my keep or delete decision.
    public var formerlySharedMomentIDs: [UUID] = []
    /// My Partner's birth date for the Lucky Day Planner. Like mine, it never leaves the phone.
    public var partnerBirthDate: Date?
    /// When the Relationship the Partner's birth date belongs to started; nil if entered while single.
    public var partnerBirthDateRelationshipSince: Date?
    /// This phone started a Recovery and is waiting out the 7 days.
    public var recoveryInProgress = false
    /// Which Lastys QR this phone shows. Each Revoke raises it by one; Trustee accepts only the latest.
    public var qrNumber = 0
    /// The Relationship request this phone sent and hasn't yet seen answered. Kept across launches so the
    /// sender still gets the Moments added on linking if they only learn of the acceptance later.
    public var sentRelationshipRequestID: String?

    public init() {}

    /// Missing fields keep their defaults, so a phone saved by an earlier version still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PhoneState()
        language = try c.decodeIfPresent(Language.self, forKey: .language) ?? defaults.language
        lastysID = try c.decodeIfPresent(LastysID.self, forKey: .lastysID)
        recoveryCode = try c.decodeIfPresent(String.self, forKey: .recoveryCode)
        hasSavedRecoveryCode = try c.decodeIfPresent(Bool.self, forKey: .hasSavedRecoveryCode) ?? defaults.hasSavedRecoveryCode
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        photo = try c.decodeIfPresent(Data.self, forKey: .photo)
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        hasFinishedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasFinishedOnboarding) ?? defaults.hasFinishedOnboarding
        shareLevel = try c.decodeIfPresent(ShareLevel.self, forKey: .shareLevel) ?? defaults.shareLevel
        // Only a cache of what Trustee said: if this build can't read it, start from nothing rather than lose the phone.
        relationship = ((try? c.decodeIfPresent(RelationshipStatus.self, forKey: .relationship)) ?? nil) ?? defaults.relationship
        isQuickHideOn = try c.decodeIfPresent(Bool.self, forKey: .isQuickHideOn) ?? defaults.isQuickHideOn
        // A Moment this build can't read is skipped on its own; the rest, and the phone, load.
        moments = ((try? c.decodeIfPresent([Skippable<Moment>].self, forKey: .moments)) ?? nil)?.compactMap(\.value) ?? defaults.moments
        partnerMoments = ((try? c.decodeIfPresent([Skippable<SharedMoment>].self, forKey: .partnerMoments)) ?? nil)?.compactMap(\.value) ?? []
        formerPartnerMoments = ((try? c.decodeIfPresent([Skippable<SharedMoment>].self, forKey: .formerPartnerMoments)) ?? nil)?.compactMap(\.value) ?? []
        hasSharedMoments = try c.decodeIfPresent(Bool.self, forKey: .hasSharedMoments) ?? false
        formerlySharedMomentIDs = ((try? c.decodeIfPresent([UUID].self, forKey: .formerlySharedMomentIDs)) ?? nil) ?? []
        partnerBirthDate = try? c.decodeIfPresent(Date.self, forKey: .partnerBirthDate)
        partnerBirthDateRelationshipSince = try? c.decodeIfPresent(Date.self, forKey: .partnerBirthDateRelationshipSince)
        recoveryInProgress = (try? c.decodeIfPresent(Bool.self, forKey: .recoveryInProgress)) ?? nil ?? false
        qrNumber = (try? c.decodeIfPresent(Int.self, forKey: .qrNumber)) ?? nil ?? 0
        sentRelationshipRequestID = (try? c.decodeIfPresent(String.self, forKey: .sentRelationshipRequestID)) ?? nil
    }
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

/// Decodes a value if it can, or nothing, so one bad element doesn't fail a whole list.
struct Skippable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
