import Foundation

/// What the owner chooses on the Moment card screen. Everything starts on, in the Rose style.
public struct MomentCardOptions: Equatable, Sendable {
    public enum Style: Sendable {
        case rose
        case dark
    }

    public var style: Style = .rose
    public var showsPhoto = true
    public var showsPlace = true
    public var showsCountdown = true
    public var showsNames = true

    public init() {}
}

/// A shareable image of one Moment, as its owner chose it. It has no field for the note or a Lastys QR,
/// and says nothing about whether anyone is single or taken, so none of those can end up on the image.
public struct MomentCard: Equatable, Sendable {
    public enum Countdown: Equatable, Sendable {
        case daysToGo(Int)
        case today
        case daysAgo(Int)
    }

    public struct Names: Equatable, Sendable {
        public let mine: String
        public let partner: String

        public init(mine: String, partner: String) {
            self.mine = mine
            self.partner = partner
        }
    }

    public let style: MomentCardOptions.Style
    public let type: MomentType
    public let title: String
    /// The Moment's own date.
    public let date: Date
    /// The photo or video to show; nil when there is none or Photo is off.
    public let photo: MomentMedia?
    /// Nil when there is no Place or Place is off.
    public let place: String?
    /// From today to the Moment's own date; nil when Countdown is off.
    public let countdown: Countdown?
    /// Both nicknames, only while in a Relationship and with Our names on.
    public let names: Names?

    /// Whether each switch is offered: only when there is something for it to show.
    public let offersPhoto: Bool
    public let offersPlace: Bool
    public let offersNames: Bool
}
