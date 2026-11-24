import Foundation

/// A person's single identity on Lastys, shown as a Personal ID such as `LT-8K2F-91QA`.
public struct LastysID: Equatable, Hashable, Codable, Sendable {
    public let personalID: String

    public init(personalID: String) {
        self.personalID = personalID
    }
}

/// Whether a Lastys ID has an active Relationship.
/// "Verified Single" and "Taken" are display labels derived from this, not states of their own.
public enum RelationshipStatus: Codable, Equatable, Sendable {
    case none
    /// In a Relationship with the Partner of this nickname, since this moment.
    case active(partnerNickname: String, since: Date)
}

/// A Relationship request this phone sent, as the sender sees it.
public struct RelationshipRequest: Equatable, Sendable {
    public enum Status: String, Sendable {
        /// Waiting for the receiver.
        case pending
        /// The receiver accepted: the Relationship has started.
        case accepted
        /// The receiver declined. Nothing else changes: no Cooling-off period starts.
        case declined
        /// No longer possible, because one of the two started a Relationship with someone else.
        case expired
    }

    public let id: String
    /// The receiver's nickname, as their Scan showed it.
    public let toNickname: String
    public let status: Status

    public init(id: String, toNickname: String, status: Status) {
        self.id = id
        self.toNickname = toNickname
        self.status = status
    }
}

/// Why a Scan can't lead to a Relationship request.
public enum RelationshipRequestBlock: Equatable, Sendable {
    /// The scanner already has an active Relationship.
    case youAreTaken
    /// The scanner's Relationship ended recently; requests are possible again from this moment.
    case youAreCoolingOff(until: Date)
    /// The scanned person already has an active Relationship.
    case theyAreTaken
    /// The scanner scanned their own Lastys QR.
    case thatIsYou
}

/// A dated event that one Lastys ID owns, such as a birthday or first date.
public struct Moment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var type: String
    public var title: String
    public var date: Date
    public var repeatsOnKhmerLunarDate: Bool

    public init(id: UUID = UUID(), type: String, title: String, date: Date, repeatsOnKhmerLunarDate: Bool = false) {
        self.id = id
        self.type = type
        self.title = title
        self.date = date
        self.repeatsOnKhmerLunarDate = repeatsOnKhmerLunarDate
    }
}

/// What a Scan of your Lastys QR shows.
public enum ShareLevel: String, Codable, Sendable {
    /// The default.
    case statusOnly = "status-only"
    case statusAndHistory = "status-and-history"
}

/// A calendar month, the only precision Relationship history keeps.
public struct YearMonth: Codable, Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
}

/// One past Relationship as a Scan may show it: when it started and ended, and nothing about the Partner.
public struct PastRelationship: Codable, Hashable, Sendable {
    public let started: YearMonth
    public let ended: YearMonth

    public init(started: YearMonth, ended: YearMonth) {
        self.started = started
        self.ended = ended
    }
}

/// What one Scan of someone's Lastys QR shows, live from Trustee.
public struct ScanResult: Equatable, Sendable {
    /// Taken or Verified Single, as a Scan shows it. Quick hide never changes this.
    public enum Status: String, Sendable {
        case single
        case taken
    }

    /// A Lastys ID younger than this many days gets a warning: it may be someone's second ID.
    public static let veryNewWithinDays = 14

    /// Names this Scan, so a Relationship request can refer to it. Only the scanner may use it.
    public let scanID: String
    public let nickname: String
    public let photo: Data?
    public let status: Status
    public let idAgeDays: Int
    public let phoneTransferCount: Int
    /// Nil when the person shares Status only: the history is hidden by its owner.
    public let relationshipHistory: [PastRelationship]?
    /// Why the scanner can't send this person a Relationship request, or nil when they can.
    public let requestBlock: RelationshipRequestBlock?

    public init(
        scanID: String,
        nickname: String,
        photo: Data?,
        status: Status,
        idAgeDays: Int,
        phoneTransferCount: Int,
        relationshipHistory: [PastRelationship]?,
        requestBlock: RelationshipRequestBlock?
    ) {
        self.scanID = scanID
        self.nickname = nickname
        self.photo = photo
        self.status = status
        self.idAgeDays = idAgeDays
        self.phoneTransferCount = phoneTransferCount
        self.relationshipHistory = relationshipHistory
        self.requestBlock = requestBlock
    }

    public var isVeryNew: Bool { idAgeDays < Self.veryNewWithinDays }
}
