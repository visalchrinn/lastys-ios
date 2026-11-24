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
public enum RelationshipStatus: Equatable, Sendable {
    case none
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
