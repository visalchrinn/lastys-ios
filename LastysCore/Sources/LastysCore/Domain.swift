import Foundation

/// A person's single identity on Lastys, shown as a Personal ID such as `LT-8K2F-91QA`.
public struct LastysID: Equatable, Hashable, Codable, Sendable {
    public let personalID: String

    public init(personalID: String) {
        self.personalID = personalID
    }
}

/// Whether a Lastys ID has an active Relationship, as its owner sees it.
/// "Verified Single" and "Taken" are display labels derived from this, not states of their own.
public enum RelationshipStatus: Codable, Equatable, Sendable {
    case none
    /// In a Relationship with the Partner of this nickname since this moment. Taken at every stage.
    case active(partnerNickname: String, since: Date, stage: RelationshipStage)
    /// A Relationship ended recently: no Relationship request can be sent or accepted until then.
    case coolingOff(until: Date)
}

/// Where an active Relationship stands. It never ends one-sidedly (ADR 0002).
public enum RelationshipStage: Codable, Equatable, Sendable {
    case together
    /// An End request is waiting for the other Partner.
    case ending(EndRequest)
    /// The Lastys team is deciding whether the Relationship ends.
    case inTeamReview(TeamReview)
}

public struct EndRequest: Codable, Equatable, Sendable {
    /// The other Partner has this many days to agree or decline.
    public static let daysToAnswer = 7

    public let sentByMe: Bool
    public let sentAt: Date
    /// The other Partner declined; the requester may now ask for a Team review.
    public let declined: Bool

    public init(sentByMe: Bool, sentAt: Date, declined: Bool) {
        self.sentByMe = sentByMe
        self.sentAt = sentAt
        self.declined = declined
    }

    /// When the 7 days to answer run out.
    public var answerBy: Date { sentAt.addingTimeInterval(Double(Self.daysToAnswer) * 86_400) }
}

public struct TeamReview: Codable, Equatable, Sendable {
    public enum Reason: String, Codable, Sendable {
        /// An End request was declined, or left unanswered for 7 days. Decided within 3 working days.
        case endRequest = "end-request"
        /// A Partner reported a safety concern. Handled within 24 hours.
        case safetyConcern = "safety-concern"
    }

    public let reason: Reason
    public let since: Date

    public init(reason: Reason, since: Date) {
        self.reason = reason
        self.since = since
    }
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

extension RelationshipStatus {
    private enum CaseKey: String, CodingKey { case none, active, coolingOff }
    private enum ActiveKey: String, CodingKey { case partnerNickname, since, stage }
    private enum CoolingOffKey: String, CodingKey { case until }

    /// The same shape Swift would generate, except that an active Relationship saved before stages
    /// existed (ticket #6) reads as together, so an upgraded phone still shows Taken.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CaseKey.self)
        if c.contains(.active) {
            let active = try c.nestedContainer(keyedBy: ActiveKey.self, forKey: .active)
            self = .active(
                partnerNickname: try active.decode(String.self, forKey: .partnerNickname),
                since: try active.decode(Date.self, forKey: .since),
                stage: try active.decodeIfPresent(RelationshipStage.self, forKey: .stage) ?? .together
            )
        } else if c.contains(.coolingOff) {
            let coolingOff = try c.nestedContainer(keyedBy: CoolingOffKey.self, forKey: .coolingOff)
            self = .coolingOff(until: try coolingOff.decode(Date.self, forKey: .until))
        } else {
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CaseKey.self)
        switch self {
        case .none:
            _ = c.nestedContainer(keyedBy: ActiveKey.self, forKey: .none)
        case .active(let partnerNickname, let since, let stage):
            var active = c.nestedContainer(keyedBy: ActiveKey.self, forKey: .active)
            try active.encode(partnerNickname, forKey: .partnerNickname)
            try active.encode(since, forKey: .since)
            try active.encode(stage, forKey: .stage)
        case .coolingOff(let until):
            var coolingOff = c.nestedContainer(keyedBy: CoolingOffKey.self, forKey: .coolingOff)
            try coolingOff.encode(until, forKey: .until)
        }
    }
}
