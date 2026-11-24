import Foundation
import LastysCore
import Network

/// Whether the phone has a usable network path right now, kept current by `NWPathMonitor`.
final class NetworkConnectivity: Connectivity, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    /// Offline until the monitor first reports a usable path, so no Scan runs on a guess.
    private var satisfied = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.withLock { self.satisfied = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "com.lastys.connectivity"))
    }

    deinit {
        monitor.cancel()
    }

    var isOnline: Bool { lock.withLock { satisfied } }
}

/// Always online, for SwiftUI previews.
struct PreviewConnectivity: Connectivity {
    var isOnline: Bool { true }
}
