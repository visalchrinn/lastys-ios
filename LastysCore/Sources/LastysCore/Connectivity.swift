/// Whether the phone can reach Trustee right now. A Scan needs it: Lastys never shows a stale status.
public protocol Connectivity: Sendable {
    var isOnline: Bool { get }
}
